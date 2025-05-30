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
                print("Detected type: \(type)")
                activityIndicator.stopAnimating()
            } catch {
                print("Error detecting type: \(error)")
                activityIndicator.stopAnimating()
            }
        }
    }
    
    @objc private func scrapeTapped() {
        activityIndicator.startAnimating()
        Task {
            do {
                let items = try await zoteroManager.scrapePage()
                print("Scraped items: \(items)")
                activityIndicator.stopAnimating()
            } catch {
                print("Error scraping page: \(error)")
                activityIndicator.stopAnimating()
            }
        }
    }
} 