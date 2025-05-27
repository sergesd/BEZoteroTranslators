import WebKit

public protocol ZoteroWebViewDelegate: AnyObject {
    func zoteroWebView(_ webView: ZoteroWebView, didDetectType type: String)
    func zoteroWebView(_ webView: ZoteroWebView, didScrapeItems items: [[String: Any]])
    func zoteroWebView(_ webView: ZoteroWebView, didFailWithError error: Error)
}

public class ZoteroWebView: WKWebView {
    public weak var zoteroDelegate: ZoteroWebViewDelegate?
    private var translatorCode: String?
    
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
        loadZoteroRuntime()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func loadZoteroRuntime() {
        // First, load the loader
        guard let loaderPath = Bundle.module.path(forResource: "loader", ofType: "js", inDirectory: "ZoteroJS"),
              let loaderCode = try? String(contentsOfFile: loaderPath) else {
            print("Error: Could not load Zotero loader")
            return
        }
        
        // Create a base URL for the ZoteroJS directory
        guard let zoteroJSURL = Bundle.module.url(forResource: "ZoteroJS", withExtension: nil) else {
            print("Error: Could not find ZoteroJS directory")
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
            console.log('Zotero runtime loaded successfully');
        }).catch(error => {
            console.error('Error loading Zotero runtime:', error);
        });
        """
        
        evaluateJavaScript(script) { [weak self] (result, error) in
            if let error = error {
                print("Error loading Zotero runtime: \(error)")
                self?.zoteroDelegate?.zoteroWebView(self!, didFailWithError: error)
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
        case "selectItems":
            // Handle item selection in your UI
            if let items = body["items"] as? [String: String] {
                // You'll need to implement this in your view controller
                // For example, show a selection UI and call resolveItemSelection
            }
            
        case "itemDone":
            if let item = body["item"] as? [String: Any] {
                zoteroDelegate?.zoteroWebView(self, didScrapeItems: [item])
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