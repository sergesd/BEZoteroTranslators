import UIKit
import WebKit

class ZoteroViewController: UIViewController {
    private var webView: WKWebView!
    private var zoteroManager: ZoteroManager!
    private var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWebView()
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
    
    private func setupWebView() {
        // Create and configure WebView
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Create and configure ZoteroManager
        zoteroManager = ZoteroManager(webView: webView)
        zoteroManager.delegate = self
        
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
        
        Task {
            do {
                try await zoteroManager.loadTranslator(translatorCode)
            } catch {
                print("Error loading translator: \(error)")
            }
        }
    }
    
    @objc private func detectTapped() {
        activityIndicator.startAnimating()
        Task {
            do {
                let type = try await zoteroManager.detectWeb()
                zoteroManager(_: zoteroManager, didDetectType: type)
            } catch {
                zoteroManager(_: zoteroManager, didFailWithError: error)
            }
        }
    }
    
    @objc private func scrapeTapped() {
        activityIndicator.startAnimating()
        Task {
            do {
                let items = try await zoteroManager.scrapePage()
                zoteroManager(_: zoteroManager, didScrapeItems: items)
            } catch {
                zoteroManager(_: zoteroManager, didFailWithError: error)
            }
        }
    }
}

// MARK: - ZoteroManagerDelegate
extension ZoteroViewController: ZoteroManagerDelegate {
    func zoteroManager(_ manager: ZoteroManager, didDetectType type: String) {
        activityIndicator.stopAnimating()
        print("Detected type: \(type)")
        // Handle the detected type (e.g., show UI, enable/disable buttons)
    }
    
    func zoteroManager(_ manager: ZoteroManager, didScrapeItems items: [[String: Any]]) {
        activityIndicator.stopAnimating()
        print("Scraped items: \(items)")
        // Handle the scraped items (e.g., save to database, show in UI)
    }
    
    func zoteroManager(_ manager: ZoteroManager, didFailWithError error: Error) {
        activityIndicator.stopAnimating()
        print("Error: \(error.localizedDescription)")
        // Show error to user
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 