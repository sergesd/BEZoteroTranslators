import WebKit

public enum ZoteroError: Error {
    case runtimeLoadFailed(String)
    case translatorLoadFailed(String)
    case detectionFailed(String)
    case scrapingFailed(String)
    case invalidResult(String)
}

public class ZoteroWebView: WKWebView {
    private var translatorCode: String?
    private var isRuntimeLoaded = false
    private var pendingTranslatorName: String?
    private var runtimeLoadContinuation: CheckedContinuation<Void, Error>?
    private var messageHandler: ((WKScriptMessage) -> Void)?
    
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        // Create a user content controller to handle JS messages
        let userContentController = WKUserContentController()
        
        // Create the configuration
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        
        super.init(frame: frame, configuration: config)
        
        // Set up message handlers
        userContentController.add(self, name: "zotero")
        
        // Load the Zotero runtime
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
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
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
        
        // Load the loader and initialize Zotero
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
        
        return try await withCheckedThrowingContinuation { continuation in
            self.runtimeLoadContinuation = continuation
            
            evaluateJavaScript(script) { [weak self] (result, error) in
                if let error = error {
                    self?.runtimeLoadContinuation?.resume(throwing: ZoteroError.runtimeLoadFailed(error.localizedDescription))
                    self?.runtimeLoadContinuation = nil
                }
            }
        }
    }
    
    public func loadTranslator(_ translatorCode: String) async throws {
        self.translatorCode = translatorCode
        print("Loading translator code...")
        
        // Split the code at the test cases marker
        let parts = translatorCode.components(separatedBy: "/** BEGIN TEST CASES **/")
        guard let actualCode = parts.first else {
            throw ZoteroError.translatorLoadFailed("Could not find translator code")
        }
        
        // First validate the JavaScript code
        let validationScript = """
        try {
            console.log('Validating translator code...');
            // Create a function from the translator code
            const translatorFunction = new Function('return ' + `\(actualCode)`);
            const translator = translatorFunction();
            console.log('Translator validation successful');
            true;
        } catch (e) {
            console.error('Translator validation failed:', e);
            throw e;
        }
        """
        
        try await evaluateJavaScript(validationScript)
        
        print("Translator validation successful, initializing translator...")
        // If we get here, the code is valid, so load it
        let script = """
        try {
            console.log('Initializing translator...');
            // Wait for Zotero to be available
            if (typeof Zotero === 'undefined') {
                throw new Error('Zotero runtime not loaded');
            }
            
            // Create a function from the translator code
            const translatorFunction = new Function('return ' + `\(actualCode)`);
            const translator = translatorFunction();
            
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
            true;
        } catch (e) {
            console.error('Error initializing translator:', e);
            throw e;
        }
        """
        
        try await evaluateJavaScript(script)
        print("Translator loaded successfully")
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
        try {
            if (!window.zoteroTranslator) {
                throw new Error('Translator not initialized');
            }
            const type = window.zoteroTranslator.detectWeb(document, window.location.href);
            if (!type) {
                throw new Error('No type detected');
            }
            type;
        } catch (e) {
            console.error('Error in detectWeb:', e);
            throw e;
        }
        """
        
        guard let type = try await evaluateJavaScript(script) as? String else {
            throw ZoteroError.detectionFailed("Invalid type returned from detectWeb")
        }
        
        return type
    }
    
    public func scrapePage() async throws -> [[String: Any]] {
        print("Starting page scrape...")
        let script = """
        try {
            console.log('Executing doWeb...');
            if (!window.zoteroTranslator) {
                throw new Error('Translator not initialized');
            }
            const result = window.zoteroTranslator.doWeb(document, window.location.href);
            if (!result || !Array.isArray(result)) {
                throw new Error('Invalid result from doWeb: ' + JSON.stringify(result));
            }
            console.log('doWeb completed with result:', result);
            result;
        } catch (e) {
            console.error('Error in doWeb:', e);
            throw e;
        }
        """
        
        guard let items = try await evaluateJavaScript(script) as? [[String: Any]] else {
            throw ZoteroError.scrapingFailed("Invalid result format from scraping")
        }
        
        if items.isEmpty {
            throw ZoteroError.scrapingFailed("No items were scraped")
        }
        
        print("Successfully scraped \(items.count) items")
        return items
    }
    
    public func resolveItemSelection(_ selectedItems: [String: String]) async throws {
        try await evaluateJavaScript("""
            window.zoteroResolveSelection(\(selectedItems));
        """)
    }
}

// MARK: - WKScriptMessageHandler
extension ZoteroWebView: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        
        switch body["type"] as? String {
        case "runtimeLoaded":
            runtimeLoadContinuation?.resume()
            runtimeLoadContinuation = nil
            
        case "error":
            if let errorMessage = body["error"] as? String {
                runtimeLoadContinuation?.resume(throwing: ZoteroError.runtimeLoadFailed(errorMessage))
                runtimeLoadContinuation = nil
            }
            
        default:
            break
        }
    }
} 