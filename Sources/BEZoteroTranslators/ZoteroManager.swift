import WebKit

public class ZoteroManager: NSObject {
    private weak var webView: WKWebView?
    private var isRuntimeLoaded = false
    private var pendingTranslatorName: String?
    private var runtimeLoadContinuation: CheckedContinuation<Void, Error>?
    private var translatorLoadContinuation: CheckedContinuation<Void, Error>?
    private var pageLoadContinuation: CheckedContinuation<Void, Error>?
    private var messageHandlers: [String: (WKScriptMessage) -> Void] = [:]
    private var retryCount = 0
    private let maxRetries = 3
    private var helperScript: WKUserScript?
    private var loaderScript: WKUserScript?
    private let scriptIdentifier = "com.bezotero.translators"
    
    public init(webView: WKWebView) {
        self.webView = webView
        super.init()
        setupMessageHandlers()
        setupWebView()
        
        // Initialize runtime asynchronously
        Task {
            do {
                try await loadZoteroRuntime()
                isRuntimeLoaded = true
                // Load any pending translator
                if let translatorName = pendingTranslatorName {
                    try await loadTranslatorByName(translatorName)
                    pendingTranslatorName = nil
                }
            } catch {
                print("Failed to load Zotero runtime: \(error)")
            }
        }
    }
    
    private func setupWebView() {
        webView?.navigationDelegate = self
    }
    
    private func setupMessageHandlers() {
        // Register default message handlers
        registerMessageHandler("runtimeLoaded") { [weak self] _ in
            self?.runtimeLoadContinuation?.resume()
            self?.runtimeLoadContinuation = nil
        }
        
        registerMessageHandler("translatorLoaded") { [weak self] _ in
            self?.translatorLoadContinuation?.resume()
            self?.translatorLoadContinuation = nil
        }
        
        registerMessageHandler("error") { [weak self] message in
            if let errorMessage = (message.body as? [String: Any])?["error"] as? String {
                self?.handleError(errorMessage)
            }
        }
        
        // Add message handler to webView
        webView?.configuration.userContentController.add(self, name: "zotero")
    }
    
    private func registerMessageHandler(_ type: String, handler: @escaping (WKScriptMessage) -> Void) {
        messageHandlers[type] = handler
    }
    
    private func handleError(_ errorMessage: String) {
        if let continuation = runtimeLoadContinuation {
            continuation.resume(throwing: ZoteroError.runtimeLoadFailed(errorMessage))
            runtimeLoadContinuation = nil
        } else if let continuation = translatorLoadContinuation {
            continuation.resume(throwing: ZoteroError.translatorLoadFailed(errorMessage))
            translatorLoadContinuation = nil
        } else if let continuation = pageLoadContinuation {
            continuation.resume(throwing: ZoteroError.pageLoadFailed(errorMessage))
            pageLoadContinuation = nil
        }
    }
    
    private func createUserScripts() throws -> (WKUserScript, WKUserScript) {
        // Load helper functions first
        guard let helpersURL = Bundle.module.url(forResource: "helpers", withExtension: "js", subdirectory: "ZoteroJS") else {
            throw ZoteroError.runtimeLoadFailed("Could not find helpers.js")
        }
        
        // Load loader.js
        guard let loaderURL = Bundle.module.url(forResource: "loader", withExtension: "js", subdirectory: "ZoteroJS") else {
            throw ZoteroError.runtimeLoadFailed("Could not find loader.js")
        }
        
        // Get the ZoteroJS directory URL from the loader's URL
        let zoteroBaseURL = loaderURL.deletingLastPathComponent()
        
        // Load helper content with proper error handling
        let helpersContent: String
        do {
            helpersContent = try String(contentsOf: helpersURL, encoding: .utf8)
        } catch {
            print("Failed to read helpers.js: \(error)")
            throw ZoteroError.runtimeLoadFailed("Could not read helpers.js: \(error.localizedDescription)")
        }
        
        // Load loader content with proper error handling
        let loaderContent: String
        do {
            loaderContent = try String(contentsOf: loaderURL, encoding: .utf8)
        } catch {
            print("Failed to read loader.js: \(error)")
            throw ZoteroError.runtimeLoadFailed("Could not read loader.js: \(error.localizedDescription)")
        }
        
        // Combine base URL and helpers into a single script
        let combinedHelpersContent = """
            // Set base URL for module loading
            window.ZOTERO_BASE_URL = '\(zoteroBaseURL.absoluteString)';
            
            // Add script identifier
            window.\(scriptIdentifier) = true;
            
            \(helpersContent)
        """
        
        // Create the scripts
        let helperScript = WKUserScript(
            source: combinedHelpersContent,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        
        let loaderScript = WKUserScript(
            source: loaderContent,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        
        return (helperScript, loaderScript)
    }
    
    private func removeOurScripts() {
        guard let webView = self.webView else { return }
        
        // Remove only our scripts
        let scripts = webView.configuration.userContentController.userScripts
        for script in scripts {
            if script.source.contains(scriptIdentifier) {
                webView.configuration.userContentController.removeUserScript(script)
            }
        }
    }
    
    public func loadZoteroRuntime() async throws {
        guard let webView = self.webView else {
            throw ZoteroError.runtimeLoadFailed("WebView is not available")
        }
        
        // Debug: Print bundle paths
        print("Bundle module path: \(Bundle.module.bundlePath)")
        print("Bundle module resource path: \(Bundle.module.resourcePath ?? "nil")")
        
        // List contents of Resources directory
        if let resourcePath = Bundle.module.resourcePath {
            print("Contents of Resources directory:")
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print(contents)
                
                // Check ZoteroJS directory contents
                let zoteroJSPath = (resourcePath as NSString).appendingPathComponent("ZoteroJS")
                if FileManager.default.fileExists(atPath: zoteroJSPath) {
                    let zoteroContents = try FileManager.default.contentsOfDirectory(atPath: zoteroJSPath)
                    print("Contents of ZoteroJS directory:")
                    print(zoteroContents)
                }
            } catch {
                print("Error listing directories: \(error)")
            }
        }
        
        do {
            // First, ensure we have a clean state
            _ = try await webView.evaluateJavaScript("ZoteroHelpers.cleanup()")
            
            // Create new scripts
            let (newHelperScript, newLoaderScript) = try createUserScripts()
            
            // Remove our existing scripts
            removeOurScripts()
            
            // Store references to our scripts
            self.helperScript = newHelperScript
            self.loaderScript = newLoaderScript
            
            // Add the scripts in the correct order
            webView.configuration.userContentController.addUserScript(newHelperScript)
            webView.configuration.userContentController.addUserScript(newLoaderScript)
            
            // Verify script injection
            guard let isInjected = try await webView.evaluateJavaScript("window.\(scriptIdentifier) === true") as? Bool,
                  isInjected else {
                throw ZoteroError.runtimeLoadFailed("Failed to inject helper scripts")
            }
            
            // Initialize Zotero using our helpers
            guard let result = try await webView.evaluateJavaScript("ZoteroHelpers.initialize()") as? Bool,
                  result == true else {
                // Cleanup on failure
                _ = try? await webView.evaluateJavaScript("ZoteroHelpers.cleanup()")
                throw ZoteroError.runtimeLoadFailed("Failed to initialize Zotero")
            }
        } catch {
            print("JavaScript evaluation error: \(error)")
            // Ensure cleanup on error
            _ = try? await webView.evaluateJavaScript("ZoteroHelpers.cleanup()")
            throw ZoteroError.runtimeLoadFailed("Failed to load Zotero runtime: \(error.localizedDescription)")
        }
    }
    
    public func loadTranslator(_ translatorCode: String) async throws {
        print("Loading translator code...")
        
        // Split the code at the test cases marker
        let parts = translatorCode.components(separatedBy: "/** BEGIN TEST CASES **/")
        guard let actualCode = parts.first else {
            throw ZoteroError.translatorLoadFailed("Could not find translator code")
        }
        
        do {
            guard let result = try await webView?.evaluateJavaScript("ZoteroHelpers.loadTranslator(\(actualCode))") as? Bool,
                  result == true else {
                throw ZoteroError.translatorLoadFailed("Failed to load translator")
            }
        } catch {
            print("JavaScript evaluation error: \(error)")
            throw ZoteroError.translatorLoadFailed("Failed to load translator: \(error.localizedDescription)")
        }
    }
    
    public func loadTranslatorByName(_ translatorName: String) async throws {
        if !isRuntimeLoaded {
            // Store the translator name to load after runtime is ready
            pendingTranslatorName = translatorName
            return
        }
        
        guard let translatorURL = Bundle.module.url(forResource: translatorName, withExtension: "js", subdirectory: "Resources/ZoteroJS/translators"),
              let translatorCode = try? String(contentsOf: translatorURL) else {
            throw ZoteroError.translatorLoadFailed("Could not load translator: \(translatorName)")
        }
        
        try await loadTranslator(translatorCode)
    }
    
    public func waitForPageLoad() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.pageLoadContinuation = continuation
        }
    }
    
    public func detectWeb() async throws -> String {
        guard let type = try await webView?.evaluateJavaScript("ZoteroHelpers.detectWeb()") as? String else {
            throw ZoteroError.detectionFailed("Invalid type returned from detectWeb")
        }
        
        return type
    }
    
    public func scrapePage() async throws -> [[String: Any]] {
        print("Starting page scrape...")
        
        // Wait for the page to load
        try await waitForPageLoad()
        
        // Try to detect the page type
        let type = try await detectWeb()
        print("Detected page type: \(type)")
        
        do {
            guard let items = try await webView?.evaluateJavaScript("ZoteroHelpers.scrape()") as? [[String: Any]] else {
                throw ZoteroError.scrapingFailed("Invalid result format from scraping")
            }
            
            if items.isEmpty {
                throw ZoteroError.scrapingFailed("No items were scraped")
            }
            
            print("Successfully scraped \(items.count) items")
            return items
        } catch {
            if retryCount < maxRetries {
                retryCount += 1
                print("Retrying scrape (attempt \(retryCount) of \(maxRetries))...")
                try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second before retry
                return try await scrapePage()
            }
            throw error
        }
    }
    
    public func resolveItemSelection(_ selectedItems: [String: String]) async throws {
        let jsonData = try JSONSerialization.data(withJSONObject: selectedItems)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ZoteroError.scrapingFailed("Failed to serialize selected items")
        }
        
        try await webView?.evaluateJavaScript("ZoteroHelpers.resolveSelection(\(jsonString))")
    }
    
    public func cleanup() {
        removeOurScripts()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "zotero")
        webView?.navigationDelegate = nil
        webView = nil
        helperScript = nil
        loaderScript = nil
    }
}

// MARK: - WKScriptMessageHandler
extension ZoteroManager: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        
        messageHandlers[type]?(message)
    }
}

// MARK: - WKNavigationDelegate
extension ZoteroManager: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageLoadContinuation?.resume()
        pageLoadContinuation = nil
        retryCount = 0 // Reset retry count on successful page load
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        pageLoadContinuation?.resume(throwing: ZoteroError.pageLoadFailed(error.localizedDescription))
        pageLoadContinuation = nil
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        pageLoadContinuation?.resume(throwing: ZoteroError.pageLoadFailed(error.localizedDescription))
        pageLoadContinuation = nil
    }
} 
