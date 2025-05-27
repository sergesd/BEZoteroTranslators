import WebKit

public protocol ZoteroWebViewDelegate: AnyObject {
    func zoteroWebView(_ webView: ZoteroWebView, didDetectType type: String)
    func zoteroWebView(_ webView: ZoteroWebView, didScrapeItems items: [[String: Any]])
    func zoteroWebView(_ webView: ZoteroWebView, didFailWithError error: Error)
}

public class ZoteroWebView: WKWebView {
    public weak var zoteroDelegate: ZoteroWebViewDelegate?
    private var translatorCode: String?
    private var isRuntimeLoaded = false
    private var pendingTranslatorName: String?
    
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
        loadZoteroRuntime { [weak self] error in
            if let error = error {
                self?.zoteroDelegate?.zoteroWebView(self!, didFailWithError: error)
            } else {
                self?.isRuntimeLoaded = true
                // Load any pending translator
                if let translatorName = self?.pendingTranslatorName {
                    self?.loadTranslatorByName(translatorName)
                    self?.pendingTranslatorName = nil
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public func loadZoteroRuntime(completion: @escaping (Error?) -> Void) {
        // First, load the loader
        guard let loaderPath = Bundle.module.path(forResource: "loader", ofType: "js", inDirectory: "Resources/ZoteroJS"),
              let loaderCode = try? String(contentsOfFile: loaderPath) else {
            completion(NSError(domain: "ZoteroWebView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load Zotero loader"]))
            return
        }
        
        // Create a base URL for the ZoteroJS directory
        guard let zoteroJSURL = Bundle.module.url(forResource: "ZoteroJS", withExtension: nil) else {
            completion(NSError(domain: "ZoteroWebView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find ZoteroJS directory"]))
            return
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
        
        evaluateJavaScript(script) { [weak self] (result, error) in
            if let error = error {
                completion(error)
            }
        }
    }
    
    public func loadTranslator(_ translatorCode: String) {
        self.translatorCode = translatorCode
        print("Loading translator code...")
        
        // Split the code at the test cases marker
        let parts = translatorCode.components(separatedBy: "/** BEGIN TEST CASES **/")
        guard let actualCode = parts.first else {
            let error = NSError(domain: "ZoteroWebView", 
                              code: -1, 
                              userInfo: [NSLocalizedDescriptionKey: "Could not find translator code"])
            zoteroDelegate?.zoteroWebView(self, didFailWithError: error)
            return
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
            throw e;  // Throw the error instead of returning it as a string
        }
        """
        
        evaluateJavaScript(validationScript) { [weak self] (result, error) in
            if let error = error {
                print("Error validating translator: \(error)")
                self?.zoteroDelegate?.zoteroWebView(self!, didFailWithError: error)
                return
            }
            
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
                throw e;  // Throw the error instead of returning it as a string
            }
            """
            
            self?.evaluateJavaScript(script) { [weak self] (result, error) in
                if let error = error {
                    print("Error loading translator: \(error)")
                    self?.zoteroDelegate?.zoteroWebView(self!, didFailWithError: error)
                    return
                }
                
                print("Translator loaded successfully")
            }
        }
    }
    
    public func loadTranslatorByName(_ translatorName: String) {
        if !isRuntimeLoaded {
            // Store the translator name to load after runtime is ready
            pendingTranslatorName = translatorName
            return
        }
        
        guard let translatorPath = Bundle.module.path(forResource: translatorName, ofType: "js", inDirectory: "Resources/ZoteroJS/translators"),
              let translatorCode = try? String(contentsOfFile: translatorPath) else {
            zoteroDelegate?.zoteroWebView(self, didFailWithError: NSError(domain: "ZoteroWebView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load translator: \(translatorName)"]))
            return
        }
        
        loadTranslator(translatorCode)
    }
    
    public func detectWeb() {
        evaluateJavaScript("""
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
        """) { [weak self] (result, error) in
            if let error = error {
                print("Error during detection: \(error)")
                self?.zoteroDelegate?.zoteroWebView(self!, didFailWithError: error)
                return
            }
            
            if let type = result as? String {
                self?.zoteroDelegate?.zoteroWebView(self!, didDetectType: type)
            } else {
                let error = NSError(domain: "ZoteroWebView", 
                                  code: -1, 
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid type returned from detectWeb"])
                self?.zoteroDelegate?.zoteroWebView(self!, didFailWithError: error)
            }
        }
    }
    
    public func scrapePage() {
        print("Starting page scrape...")
        evaluateJavaScript("""
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
        """) { [weak self] (result, error) in
            if let error = error {
                print("Error during scraping: \(error)")
                self?.zoteroDelegate?.zoteroWebView(self!, didFailWithError: error)
                return
            }
            
            print("Scraping completed with result: \(String(describing: result))")
            if let items = result as? [[String: Any]] {
                if items.isEmpty {
                    let error = NSError(domain: "ZoteroWebView", 
                                      code: -1, 
                                      userInfo: [NSLocalizedDescriptionKey: "No items were scraped"])
                    self?.zoteroDelegate?.zoteroWebView(self!, didFailWithError: error)
                    return
                }
                print("Successfully scraped \(items.count) items")
                self?.zoteroDelegate?.zoteroWebView(self!, didScrapeItems: items)
            } else {
                let error = NSError(domain: "ZoteroWebView", 
                                  code: -1, 
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid result format from scraping"])
                self?.zoteroDelegate?.zoteroWebView(self!, didFailWithError: error)
            }
        }
    }
    
    public func resolveItemSelection(_ selectedItems: [String: String]) {
        evaluateJavaScript("""
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
            isRuntimeLoaded = true
            if let translatorName = pendingTranslatorName {
                loadTranslatorByName(translatorName)
                pendingTranslatorName = nil
            }
            
        case "error":
            if let errorMessage = body["error"] as? String {
                let error = NSError(domain: "ZoteroWebView", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                zoteroDelegate?.zoteroWebView(self, didFailWithError: error)
            }
            
        default:
            break
        }
    }
} 