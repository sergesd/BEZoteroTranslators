//
//  TranslationWebViewHandler.swift
//  BEZoteroTranslators
//
//  Created based on ZShare
//

import Foundation
import WebKit

@MainActor
final class TranslationWebViewHandler: WebViewHandler {

    // Not used, yet, better to use with AsyncStream
    /// Actions that can be returned by this handler.
//    enum Action {
//        case loadedItems(data: [[String: Any]], cookies: String?, userAgent: String?, referrer: String?)
//        case selectItem([(key: String, value: String)])
//        case reportProgress(String)
//    }

    /// Handlers for communication with JS in `webView`
    enum JSHandlers: String, CaseIterable {
        case request = "requestHandler"
        case item = "itemResponseHandler"
        case itemSelection = "itemSelectionHandler"
        case saveAsWeb = "saveAsWebHandler"
        case progress = "translationProgressHandler"
        case log = "logHandler"
    }

    enum Error: Swift.Error {
        case cantFindFile
        case incompatibleItem
        case javascriptCallMissingResult
        case noSuccessfulTranslators
    }
    
    // Translation state for error classification
    private enum TranslationState {
        case idle
        case translating
        case completed
        case failed
    }

    private let translatorManager: TranslatorManager
    
    // Callbacks for async operations
    private var onLoadedItems: (([[String: Any]], String?, String?, String?) -> Void)?
    private var onSelectItems: (([(String, String)]) -> Void)?
    private var onProgress: ((String) -> Void)?
    private var onError: ((Error) -> Void)?

    private var itemSelectionMessageId: Int?
    
    // Translation state tracking
    private var translationState: TranslationState = .idle
    private var hasReceivedItems = false

    // MARK: - Lifecycle

    init(webView: WKWebView, translatorManager: TranslatorManager) {
        self.translatorManager = translatorManager

        super.init(webView: webView, javascriptHandlers: JSHandlers.allCases.map({ $0.rawValue }))

        receivedMessageHandler = { [weak self] name, body in
            self?.receiveMessage(name: name, body: body)
        }
    }

    // MARK: - Public API
    
    /// Set up callbacks for translation events
    func setCallbacks(
        onLoadedItems: @escaping ([[String: Any]], String?, String?, String?) -> Void,
        onSelectItems: @escaping ([(String, String)]) -> Void,
        onProgress: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onLoadedItems = onLoadedItems
        self.onSelectItems = onSelectItems
        self.onProgress = onProgress
        self.onError = onError
    }

    // MARK: - Actions

    /// Runs translation server against html content with cookies using async/await
    func translate(url: URL, title: String, html: String, cookies: String, frames: [String], userAgent: String, referrer: String) async throws {
        print("TranslationWebViewHandler: translate")
        
        // Reset translation state
        translationState = .translating
        hasReceivedItems = false
        
        // Initialize the web view
        try await performAfterInitialization()
        
        // Set cookies and user agent
        set(cookies: cookies, userAgent: userAgent, referrer: referrer)
        
        // Load index
        try await loadIndex()
        
        // Load bundled files
        let (encodedSchema, encodedDateFormats) = try await loadBundledFiles()
        
        // Initialize schema and date formats
        try await execute(javascript: "initSchemaAndDateFormats(\(encodedSchema), \(encodedDateFormats));")
        
        // Load translators
        print("TranslationWebViewHandler: load translators")
        let translatorEntries = try await translatorManager.translators(matching: url.absoluteString)
        
        // Load complete translator data (code and metadata) for each entry
        print("TranslationWebViewHandler: encode complete translator data")
        var completeTranslators: [[String: Any]] = []
        
        func translatorToSendToJS(translator: EnhancedTranslatorEntry, completeTranslators: inout [[String: Any]]) {
            //var TRANSLATOR_REQUIRED_PROPERTIES = ["translatorID", "translatorType", "label", "creator",
            //    "target", "priority", "lastUpdated"];

            guard var metadata = translator.metadata,
                  let code = translator.code else {
                print("TranslationWebViewHandler: Skipping translator '\(translator.id)' - missing metadata or code")
                return
            }

            metadata["code"] = code
            
            completeTranslators.append(metadata)
            
            if let dependencies = translator.dependencies {
                for dependency in dependencies {
                    translatorToSendToJS(translator: dependency, completeTranslators: &completeTranslators)
                }
            }
        }
        
        for translator in translatorEntries {
            translatorToSendToJS(translator: translator, completeTranslators: &completeTranslators)
        }
        
        print("TranslationWebViewHandler: Loaded \(translatorEntries.count) translator entries, sending \(completeTranslators.count) complete translators to JS")
        
        let encodedTranslators = WebViewEncoder.encodeAsJSONForJavascript(completeTranslators)
        try await execute(javascript: "initTranslators(\(encodedTranslators));")
        
        // Call translate JavaScript
        print("TranslationWebViewHandler: call translate js")
        let encodedHtml = WebViewEncoder.encodeForJavascript(html.data(using: .utf8))
        let jsonFramesData = try? JSONSerialization.data(withJSONObject: frames, options: .fragmentsAllowed)
        let encodedFrames = jsonFramesData.flatMap({ WebViewEncoder.encodeForJavascript($0) }) ?? "''"
        
        // Call the async function without expecting a return value
        // The translate function communicates results via message handlers, not return values
        try await execute(javascript: "translate('\(url.absoluteString)', \(encodedHtml), \(encodedFrames));")
    }

    /// Sends selected item back to `webView`.
    func selectItem(_ item: (String, String)) {
        guard let messageId = itemSelectionMessageId else { return }
        let (key, value) = item
        sendMessaging(response: [key: value], for: messageId)
        itemSelectionMessageId = nil
    }
    
    /// Sends multiple selected items back to `webView`.
    public func selectItems(_ items: [(String, String)]) {
        guard let messageId = itemSelectionMessageId else { return }
        
        // Convert array of tuples to object that JavaScript expects
        var selectedItems: [String: Any] = [:]
        for (key, value) in items {
            selectedItems[key] = ["title": value]
        }
        
        sendMessagingWithErrorHandling(response: selectedItems, for: messageId)
    }
    
    /// Override sendMessaging to add error classification
    private func sendMessagingWithErrorHandling(response payload: [String: Any], for messageId: Int) {
        let script = "Zotero.Messaging.receiveResponse('\(messageId)', \(WebViewEncoder.encodeAsJSONForJavascript(payload)));"
        Task { @MainActor in
            do {
                try await execute(javascript: script)
            } catch {
                // Classify the error
                if isCriticalError(error) {
                    print("TranslationWebViewHandler: Critical error sending message response: \(error)")
                    onError?(Error.javascriptCallMissingResult)
                } else {
                    print("TranslationWebViewHandler: Non-critical error sending message response: \(error)")
                }
            }
        }
    }
    
    /// Classifies errors as critical or non-critical based on translation state
    private func isCriticalError(_ error: Swift.Error) -> Bool {
        // WKErrorDomain Code=5 errors are non-critical if translation already completed
        if let nsError = error as NSError?,
           nsError.domain == "WKErrorDomain" && nsError.code == 5 {
            // If we've received items successfully, this is likely a cleanup error
            if hasReceivedItems || translationState == .completed {
                print("TranslationWebViewHandler: Non-critical WKErrorDomain Code=5 error (translation completed successfully)")
                return false
            }
        }
        
        // All other errors during translation are critical
        if translationState == .translating {
            return true
        }
        
        // Errors after completion are non-critical
        return false
    }

    // MARK: - Private Methods

    private func loadIndex() async throws -> () {
        guard let indexUrl = Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "TranslationEngine/translation") else {
            throw Error.cantFindFile
        }
        return try await load(fileUrl: indexUrl)
    }

    private func loadBundledFiles() async throws -> (String, String) {
        guard let schemaUrl = Bundle.module.url(forResource: "schema", withExtension: "json", subdirectory: "TranslationEngine/translation/translate/modules/utilities/resource/schema/global"),
              let schemaData = try? Data(contentsOf: schemaUrl) else {
            print("TranslationWebViewHandler: can't load schema json")
            throw Error.cantFindFile
        }

        guard let dateFormatsUrl = Bundle.module.url(forResource: "dateFormats", withExtension: "json", subdirectory: "TranslationEngine/translation/translate/modules/utilities/resource"),
              let dateFormatData = try? Data(contentsOf: dateFormatsUrl)
        else {
            print("TranslationWebViewHandler: can't load dateFormats json")
            throw Error.cantFindFile
        }

        let encodedSchema = WebViewEncoder.encodeForJavascript(schemaData)
        let encodedFormats = WebViewEncoder.encodeForJavascript(dateFormatData)

        print("TranslationWebViewHandler: loaded bundled files")

        return (encodedSchema, encodedFormats)
    }

    /// Communication with JS in `webView`. The `webView` sends a message through one of the registered `JSHandlers`, which is received here.
    private func receiveMessage(name: String, body: Any) {
        print("TranslationWebViewHandler: Received message - \(name): \(body)")
        guard let handler = JSHandlers(rawValue: name) else { 
            print("TranslationWebViewHandler: Unknown handler - \(name)")
            return 
        }

        switch handler {
        case .request:
            guard let body = body as? [String: Any], let messageId = body["messageId"] as? Int else {
                print("TranslationWebViewHandler: request missing body - \(body)")
                return
            }

            if let options = body["payload"] as? [String: Any] {
                sendRequest(with: options, for: messageId)
            } else {
                print("TranslationWebViewHandler: request missing payload - \(body)")
                sendMessaging(error: "HTTP request missing payload", for: messageId)
            }

        case .itemSelection:
            // Handle the actual structure being sent
            if let body = body as? [String: Any],
               let messageId = body["messageId"] as? Int,
               let payload = body["payload"] as? [Any] {
                
                itemSelectionMessageId = messageId

                var sortedDictionary: [(String, String)] = []
                for item in payload {
                    // Each item is a tuple: (String, Dictionary)
                    if let tuple = item as? [Any],
                       tuple.count == 2,
                       let key = tuple[0] as? String,
                       let dict = tuple[1] as? [String: Any],
                       let title = dict["title"] as? String {
                        sortedDictionary.append((key, title))
                    }
                }

                        onSelectItems?(sortedDictionary)
            } else {
                print("TranslationWebViewHandler: item selection missing payload - \(body)")
                if let body = body as? [String: Any],
                   let messageId = body["messageId"] as? Int {
                    sendMessaging(error: "Item selection missing payload", for: messageId)
                }
            }

        case .item:
            if let info = body as? [[String: Any]] {
                // Mark translation as completed successfully
                translationState = .completed
                hasReceivedItems = true
                
                // For now, let's skip the itemToAPIJSON processing and just fix the Snapshot URLs in Swift
                // We'll implement a simpler Swift-side fix for CURRENT_TIMESTAMP and Snapshot URLs
                Task {
                    do {
                        let processedItems = try await processItemsInSwift(info)
                        await MainActor.run {
                            // Pass the actual cookies, userAgent, and referer that were used for translation
                            self.onLoadedItems?(processedItems, self.cookies, self.userAgent, self.referer)
                        }
                    } catch {
                        await MainActor.run {
                            print("TranslationWebViewHandler: Failed to process items: \(error)")
                            // Fall back to original items if processing fails
                            self.onLoadedItems?(info, self.cookies, self.userAgent, self.referer)
                        }
                    }
                }
            } else {
                print("TranslationWebViewHandler: got incompatible body - \(body)")
                translationState = .failed
                onError?(Error.incompatibleItem)
            }

        case .progress:
            if let progress = body as? String {
                if progress == "item_selection" {
                    onProgress?("Item selection")
                } else if progress.starts(with: "translating_with_") {
                    let name = progress[progress.index(progress.startIndex, offsetBy: 17)..<progress.endIndex]
                    print("TranslationWebViewHandler: Trying translator: \(name)")
                    onProgress?("Translating with \(name)")
                } else {
                    print("TranslationWebViewHandler: Progress: \(progress)")
                    onProgress?(progress)
                }
            }

        case .saveAsWeb:
            print("TranslationWebViewHandler: All translators failed, calling saveAsWeb")
            translationState = .failed
            onError?(Error.noSuccessfulTranslators)

        case .log:
            print("TranslationWebViewHandler: JSLOG - \(body)")
            
        case _:
            print("TranslationWebViewHandler: Received unhandled message - \(name): \(body)")
        }
    }
    
    // MARK: - Item Processing
    
    /// Process translation items in Swift to fix CURRENT_TIMESTAMP (like ZShare does)
    private func processItemsInSwift(_ items: [[String: Any]]) async throws -> [[String: Any]] {
        print("TranslationWebViewHandler: Processing \(items.count) items in Swift")
        
        var processedItems: [[String: Any]] = []
        
        for (index, item) in items.enumerated() {
            var processedItem = item
            
            // Fix CURRENT_TIMESTAMP in accessDate (same approach as ZShare)
            if let accessDate = processedItem["accessDate"] as? String, accessDate == "CURRENT_TIMESTAMP" {
                let formatter = ISO8601DateFormatter()
                let currentDate = formatter.string(from: Date())
                processedItem["accessDate"] = currentDate
                print("TranslationWebViewHandler: Fixed accessDate for item \(index): \(currentDate)")
            }
            
            processedItems.append(processedItem)
        }
        
        print("TranslationWebViewHandler: Successfully processed \(processedItems.count) items in Swift")
        return processedItems
    }
}

