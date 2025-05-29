import WebKit

public protocol ZoteroManagerDelegate: AnyObject {
    func zoteroManager(_ manager: ZoteroManager, didDetectType type: String)
    func zoteroManager(_ manager: ZoteroManager, didScrapeItems items: [[String: Any]])
    func zoteroManager(_ manager: ZoteroManager, didFailWithError error: Error)
}

public class ZoteroManager: NSObject {
    private weak var webView: WKWebView?
    private var isRuntimeLoaded = false
    private var pendingTranslatorName: String?
    private var runtimeLoadContinuation: CheckedContinuation<Void, Error>?
    private var translatorLoadContinuation: CheckedContinuation<Void, Error>?
    private var messageHandlers: [String: (WKScriptMessage) -> Void] = [:]
    
    public weak var delegate: ZoteroManagerDelegate?
    
    public init(webView: WKWebView) {
        self.webView = webView
        super.init()
        setupMessageHandlers()
        loadZoteroRuntime()
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
        }
    }
    
    private func loadZoteroRuntime() {
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
    
    public func loadZoteroRuntime() async throws {
        // First, load the loader
        guard let loaderPath = Bundle.module.path(forResource: "loader", ofType: "js", inDirectory: "Resources/ZoteroJS"),
              let loaderCode = try? String(contentsOfFile: loaderPath) else {
            throw ZoteroError.runtimeLoadFailed("Could not load Zotero loader")
        }
        
        // Create a base URL for the ZoteroJS directory
        guard let zoteroJSURL = Bundle.module.url(forResource: "ZoteroJS", withExtension: nil) else {
            throw ZoteroError.runtimeLoadFailed("Could not find ZoteroJS directory")
        }
        
        // Create the initialization script
        let script = """
        // Set base URL for Zotero modules
        window.ZOTERO_BASE_URL = '\(zoteroJSURL.absoluteString)';
        
        // Load the loader
        \(loaderCode)
        
        // Initialize Zotero
        ZoteroLoader.load().then(() => {
            window.webkit.messageHandlers.zotero.postMessage({
                type: 'runtimeLoaded'
            });
        }).catch(error => {
            window.webkit.messageHandlers.zotero.postMessage({
                type: 'error',
                error: error.toString()
            });
        });
        """
        
        // Create and add the user script synchronously
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        
        // Add the user script synchronously
        if let webView = webView {
            webView.configuration.userContentController.addUserScript(userScript)
        }
        
        // Wait for the runtime to load
        return try await withCheckedThrowingContinuation { continuation in
            self.runtimeLoadContinuation = continuation
        }
    }
    
    public func loadTranslator(_ translatorCode: String) async throws {
        print("Loading translator code...")
        
        // Split the code at the test cases marker
        let parts = translatorCode.components(separatedBy: "/** BEGIN TEST CASES **/")
        guard let actualCode = parts.first else {
            throw ZoteroError.translatorLoadFailed("Could not find translator code")
        }
        
        // Create a wrapper script that will handle initialization and error reporting
        let script = """
        (function() {
            try {
                console.log('Initializing translator...');
                // Wait for Zotero to be available
                if (typeof Zotero === 'undefined') {
                    throw new Error('Zotero runtime not loaded');
                }
                
                // Create a function from the translator code
                const translatorFunction = new Function('return ' + `\(actualCode)`);
                const translator = translatorFunction();
                
                // Validate required functions
                const requiredFunctions = ['detectWeb', 'doWeb'];
                for (const func of requiredFunctions) {
                    if (typeof translator[func] !== 'function') {
                        throw new Error(`Missing required function: ${func}`);
                    }
                }
                
                // Create a new translator instance
                window.zoteroTranslator = new Zotero.Translator('web');
                
                // Copy the functions from our translator
                window.zoteroTranslator.detectWeb = translator.detectWeb;
                window.zoteroTranslator.doWeb = translator.doWeb;
                window.zoteroTranslator.getSearchResults = translator.getSearchResults;
                window.zoteroTranslator.scrape = translator.scrape;
                
                // Set up the translator
                window.zoteroTranslator.setTranslator('951c027d-74ac-47d4-a107-9c3069ab7b48');
                window.zoteroTranslator.setDocument(document);
                
                console.log('Translator initialized successfully');
                window.webkit.messageHandlers.zotero.postMessage({
                    type: 'translatorLoaded'
                });
            } catch (e) {
                console.error('Error initializing translator:', e);
                window.webkit.messageHandlers.zotero.postMessage({
                    type: 'error',
                    error: e.toString()
                });
                throw e;
            }
        })();
        """
        
        // Create and add the user script
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        
        // Remove any existing translator scripts
        webView?.configuration.userContentController.removeAllUserScripts()
        
        // Add the new translator script
        webView?.configuration.userContentController.addUserScript(userScript)
        
        // Wait for the translator to be loaded
        return try await withCheckedThrowingContinuation { continuation in
            self.translatorLoadContinuation = continuation
        }
    }
    
    public func loadTranslatorByName(_ translatorName: String) async throws {
        if !isRuntimeLoaded {
            // Store the translator name to load after runtime is ready
            pendingTranslatorName = translatorName
            return
        }
        
        guard let translatorPath = Bundle.module.path(forResource: translatorName, ofType: "js", inDirectory: "Resources/ZoteroJS/translators"),
              let translatorCode = try? String(contentsOfFile: translatorPath) else {
            throw ZoteroError.translatorLoadFailed("Could not load translator: \(translatorName)")
        }
        
        try await loadTranslator(translatorCode)
    }
    
    public func detectWeb() async throws -> String {
        let script = """
        (function() {
            try {
                if (!window.zoteroTranslator) {
                    throw new Error('Translator not initialized');
                }
                
                // Validate translator state
                if (!window.zoteroTranslator.detectWeb) {
                    throw new Error('Translator missing detectWeb function');
                }
                
                const type = window.zoteroTranslator.detectWeb(document, window.location.href);
                if (!type) {
                    throw new Error('No type detected');
                }
                
                // Validate the detected type
                if (typeof type !== 'string') {
                    throw new Error('Invalid type returned: ' + typeof type);
                }
                
                return type;
            } catch (e) {
                console.error('Error in detectWeb:', e);
                window.webkit.messageHandlers.zotero.postMessage({
                    type: 'error',
                    error: e.toString()
                });
                throw e;
            }
        })();
        """
        
        guard let type = try await webView?.evaluateJavaScript(script) as? String else {
            throw ZoteroError.detectionFailed("Invalid type returned from detectWeb")
        }
        
        return type
    }
    
    public func scrapePage() async throws -> [[String: Any]] {
        print("Starting page scrape...")
        let script = """
        (function() {
            try {
                console.log('Executing doWeb...');
                if (!window.zoteroTranslator) {
                    throw new Error('Translator not initialized');
                }
                
                // Validate translator state
                if (!window.zoteroTranslator.doWeb) {
                    throw new Error('Translator missing doWeb function');
                }
                
                const result = window.zoteroTranslator.doWeb(document, window.location.href);
                
                // Validate result
                if (!result) {
                    throw new Error('No result returned from doWeb');
                }
                
                if (!Array.isArray(result)) {
                    throw new Error('Invalid result type: ' + typeof result);
                }
                
                // Validate each item in the result
                for (let i = 0; i < result.length; i++) {
                    const item = result[i];
                    if (typeof item !== 'object') {
                        throw new Error(`Invalid item type at index ${i}: ${typeof item}`);
                    }
                    
                    // Check for required fields
                    const requiredFields = ['itemType', 'title'];
                    for (const field of requiredFields) {
                        if (!(field in item)) {
                            throw new Error(`Missing required field '${field}' in item at index ${i}`);
                        }
                    }
                }
                
                console.log('doWeb completed with result:', result);
                return result;
            } catch (e) {
                console.error('Error in doWeb:', e);
                window.webkit.messageHandlers.zotero.postMessage({
                    type: 'error',
                    error: e.toString()
                });
                throw e;
            }
        })();
        """
        
        guard let items = try await webView?.evaluateJavaScript(script) as? [[String: Any]] else {
            throw ZoteroError.scrapingFailed("Invalid result format from scraping")
        }
        
        if items.isEmpty {
            throw ZoteroError.scrapingFailed("No items were scraped")
        }
        
        print("Successfully scraped \(items.count) items")
        return items
    }
    
    public func resolveItemSelection(_ selectedItems: [String: String]) async throws {
        try await webView?.evaluateJavaScript("""
            window.zoteroResolveSelection(\(selectedItems));
        """)
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
