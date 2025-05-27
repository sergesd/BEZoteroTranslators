import UIKit
import WebKit

class ZoteroViewController: UIViewController {
    private var zoteroWebView: ZoteroWebView!
    private var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupZoteroWebView()
    }
    
    private func setupUI() {
        // Add activity indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Add navigation bar buttons
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Detect", style: .plain, target: self, action: #selector(detectTapped)),
            UIBarButtonItem(title: "Scrape", style: .plain, target: self, action: #selector(scrapeTapped))
        ]
    }
    
    private func setupZoteroWebView() {
        // Create and configure ZoteroWebView
        zoteroWebView = ZoteroWebView(frame: .zero, configuration: WKWebViewConfiguration())
        zoteroWebView.translatesAutoresizingMaskIntoConstraints = false
        zoteroWebView.zoteroDelegate = self
        view.addSubview(zoteroWebView)
        
        NSLayoutConstraint.activate([
            zoteroWebView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            zoteroWebView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            zoteroWebView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            zoteroWebView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Load a sample translator
        loadSampleTranslator()
    }
    
    private func loadSampleTranslator() {
        // Load the Washington Post translator as an example
        guard let translatorPath = Bundle.main.path(forResource: "Washington Post", ofType: "js"),
              let translatorCode = try? String(contentsOfFile: translatorPath) else {
            print("Error: Could not load translator")
            return
        }
        
        zoteroWebView.loadTranslator(translatorCode)
    }
    
    @objc private func detectTapped() {
        activityIndicator.startAnimating()
        zoteroWebView.detectWeb()
    }
    
    @objc private func scrapeTapped() {
        activityIndicator.startAnimating()
        zoteroWebView.scrapePage()
    }
}

// MARK: - ZoteroWebViewDelegate
extension ZoteroViewController: ZoteroWebViewDelegate {
    func zoteroWebView(_ webView: ZoteroWebView, didDetectType type: String) {
        activityIndicator.stopAnimating()
        print("Detected type: \(type)")
        // Handle the detected type (e.g., show UI, enable/disable buttons)
    }
    
    func zoteroWebView(_ webView: ZoteroWebView, didScrapeItems items: [[String: Any]]) {
        activityIndicator.stopAnimating()
        print("Scraped items: \(items)")
        // Handle the scraped items (e.g., save to database, show in UI)
    }
    
    func zoteroWebView(_ webView: ZoteroWebView, didFailWithError error: Error) {
        activityIndicator.stopAnimating()
        print("Error: \(error.localizedDescription)")
        // Show error to user
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 