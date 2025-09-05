//
//  WebViewHandler.swift
//  BEZoteroTranslators
//
//  Created based on ZShare
//

import Foundation
import WebKit

@MainActor
class WebViewHandler: NSObject {
    enum Error: Swift.Error {
        case webViewMissing
        case urlMissingTranslators
    }

    private enum InitializationState {
        case initialized
        case inProgress
        case failed(Swift.Error)
    }

    private let session: URLSession
    private weak var webView: WKWebView?
    private var webDidLoad: ((Result<(), Swift.Error>) -> Void)?
    var receivedMessageHandler: ((String, Any) -> Void)?
    
    // Cookies, User-Agent and Referrer from original website are stored and added to requests in `sendRequest(with:)`.
    private(set) var cookies: String?
    private(set) var userAgent: String?
    private(set) var referer: String?
    private var initializationState: InitializationState = .inProgress
    private var initializationContinuation: CheckedContinuation<(), Swift.Error>?

    // MARK: - Lifecycle

    init(webView: WKWebView, javascriptHandlers: [String]?) {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always

        session = URLSession(configuration: configuration)
        self.webView = webView

        super.init()

        webView.navigationDelegate = self
        let userAgent = webView.value(forKey: "userAgent") ?? ""
        webView.customUserAgent = "\(userAgent) BEZoteroTranslators/1.0"

        javascriptHandlers?.forEach { handler in
            webView.configuration.userContentController.removeScriptMessageHandler(forName: handler)
            webView.configuration.userContentController.add(self, name: handler)
        }

#if DEBUG
        if #available(iOS 16.4, macOS 13.3, *) {
            webView.isInspectable = true
        }
#endif
        
        Task {
            do {
                try await initializeWebView()
                print("WebViewHandler: initialization succeeded")
                initializationState = .initialized
            } catch {
                print("WebViewHandler: initialization failed - \(error)")
                initializationState = .failed(error)
            }
        }
    }

    // MARK: - Actions

    /// Method to be overriden by subclasses. Default implementation just assumes web view is already initialized.
    func initializeWebView() async throws {
        // Default implementation - assume already initialized
    }

    func performAfterInitialization() async throws {
        switch initializationState {
        case .initialized:
            return
        case .failed(let error):
            throw error
        case .inProgress:
            // Wait for initialization to complete
            return try await withCheckedThrowingContinuation { continuation in
                self.initializationContinuation = continuation
            }
        }
    }

    func set(cookies: String?, userAgent: String?, referrer: String?) {
        self.cookies = cookies
        self.userAgent = userAgent
        self.referer = referrer
    }

    func load(fileUrl: URL) async throws {
        guard let webView else {
            print("WebViewHandler: web view is nil")
            throw Error.webViewMissing
        }
        await webView.loadFileURL(fileUrl, allowingReadAccessTo: fileUrl.deletingLastPathComponent())
        try await waitForWebViewLoad()
    }

    func load(webUrl: URL) async throws {
        guard let webView else {
            print("WebViewHandler: web view is nil")
            throw Error.webViewMissing
        }
        let request = URLRequest(url: webUrl)
        await webView.load(request)
        try await waitForWebViewLoad()
    }

    func call(javascript: String) async throws -> Any {
        guard let webView else {
            print("WebViewHandler: web view is nil")
            throw Error.webViewMissing
        }
        return try await webView.call(javascript: javascript)
    }
    
    /// Execute JavaScript without expecting a return value
    func execute(javascript: String) async throws {
        guard let webView else {
            print("WebViewHandler: web view is nil")
            throw Error.webViewMissing
        }
        try await webView.execute(javascript: javascript)
    }

    func sendMessaging(response payload: [String: Any], for messageId: Int) {
        let script = "Zotero.Messaging.receiveResponse('\(messageId)', \(WebViewEncoder.encodeAsJSONForJavascript(payload)));"
        DispatchQueue.main.async { [weak self] in
            Task {
                do {
                    try await self?.webView?.execute(javascript: script)
                } catch {
                    print("WebViewHandler: Error sending message response: \(error)")
                }
            }
        }
    }

    func sendHttpResponse(data: Data?, statusCode: Int, url: URL?, successCodes: [Int], headers: [AnyHashable: Any], for messageId: Int) {
        let isSuccess = successCodes.isEmpty ? 200..<300 ~= statusCode : successCodes.contains(statusCode)
        let responseText = data.flatMap({ String(data: $0, encoding: .utf8) }) ?? ""

        var payload: [String: Any]
        if isSuccess {
            payload = ["status": statusCode, "responseText": responseText, "headers": headers, "url": url?.absoluteString ?? ""]
        } else {
            payload = ["error": ["status": statusCode, "responseText": responseText] as [String: Any]]
        }

        sendMessaging(response: payload, for: messageId)
    }

    func sendMessaging(error: String, for messageId: Int) {
        sendMessaging(response: ["error": ["message": error]], for: messageId)
    }

    func removeFromSuperviewAsynchronously() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let webView else { return }
            webView.configuration.userContentController.removeAllScriptMessageHandlers()
            webView.removeFromSuperview()
        }
    }

    // MARK: - HTTP Requests

    /// Sends HTTP request based on options. Sends back response with HTTP response to `webView`.
    /// - parameter options: Options for HTTP request.
    func sendRequest(with options: [String: Any], for messageId: Int) {
        guard let urlString = options["url"] as? String,
              let url = URL(string: urlString) ?? urlString.removingPercentEncoding.flatMap({ $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap(URL.init) }),
              let method = options["method"] as? String else {
            print("Incorrect URL request from javascript")
            print("\(options)")

            let data = "Incorrect URL request from javascript".data(using: .utf8)
            sendHttpResponse(data: data, statusCode: -1, url: nil, successCodes: [200], headers: [:], for: messageId)
            return
        }

        guard !urlString.contains("repo/code/undefined") else {
            print("WebViewHandler: Undefined call, translator missing.")
            sendHttpResponse(data: "Translator missing".data(using: .utf8), statusCode: -1, url: nil, successCodes: [200], headers: [:], for: messageId)
            return
        }

        let headers = (options["headers"] as? [String: String]) ?? [:]
        let body = options["body"] as? String
        let timeout = (options["timeout"] as? Double).flatMap({ $0 / 1000 }) ?? 60
        let successCodes = (options["successCodes"] as? [Int]) ?? []

        print("WebViewHandler: send request to \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if headers["User-Agent"] == nil, let userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        if headers["Referer"] == nil, let referer, !referer.isEmpty {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        // Forward page cookies to URLSession requests if not explicitly provided
        if headers["Cookie"] == nil, let cookies, !cookies.isEmpty {
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
        }
        request.httpBody = body?.data(using: .utf8)
        request.timeoutInterval = timeout

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let response = response as? HTTPURLResponse {
                self.sendHttpResponse(data: data, statusCode: response.statusCode, url: response.url, successCodes: successCodes, headers: response.allHeaderFields, for: messageId)
            } else if let error {
                self.sendHttpResponse(data: error.localizedDescription.data(using: .utf8), statusCode: -1, url: nil, successCodes: successCodes, headers: [:], for: messageId)
            } else {
                self.sendHttpResponse(data: "unknown error".data(using: .utf8), statusCode: -1, url: nil, successCodes: successCodes, headers: [:], for: messageId)
            }
        }
        task.resume()
    }

    /// Wait for webview to load a resource
    private func waitForWebViewLoad() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.webDidLoad = { result in
                continuation.resume(with: result)
            }
        }
    }
}

extension WebViewHandler: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for javascript to load
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            self.webDidLoad?(.success(()))
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Swift.Error) {
        print("WebViewHandler: did fail - \(error)")
        webDidLoad?(.failure(error))
    }
}

/// Communication with JS in `webView`. The `webView` sends a message through one of the registered `JSHandlers`, which is received here.
/// Each message contains a `messageId` in the body, which is used to identify the message in case a response is expected.
extension WebViewHandler: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        DispatchQueue.main.async {
            self.receivedMessageHandler?(message.name, message.body)
        }
    }
}



// MARK: - WKWebView Extension

extension WKWebView {
    func call(javascript: String) async throws -> Any {
        return try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(javascript) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result as Any)
                }
            }
        }
    }
    
    func execute(javascript: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(javascript) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
