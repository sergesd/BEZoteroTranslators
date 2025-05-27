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
        
        let script = """
        // Initialize translator
        window.zoteroTranslator = new Zotero.Translator(\(translatorCode));
        """
        
        evaluateJavaScript(script) { [weak self] (result, error) in
            if let error = error {
                print("Error loading translator: \(error)")
                self?.zoteroDelegate?.zoteroWebView(self!, didFailWithError: error)
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
            window.zoteroTranslator.detectWeb(document, window.location.href)
        """) { [weak self] (result, error) in
            if let error = error {
                self?.zoteroDelegate?.zoteroWebView(self!, didFailWithError: error)
                return
            }
            
            if let type = result as? String {
                self?.zoteroDelegate?.zoteroWebView(self!, didDetectType: type)
            }
        }
    }
    
    public func scrapePage() {
        evaluateJavaScript("""
            window.zoteroTranslator.doWeb(document, window.location.href)
        """) { [weak self] (result, error) in
            if let error = error {
                self?.zoteroDelegate?.zoteroWebView(self!, didFailWithError: error)
                return
            }
            
            if let items = result as? [[String: Any]] {
                self?.zoteroDelegate?.zoteroWebView(self!, didScrapeItems: items)
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