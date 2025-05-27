# BEZoteroTranslators

A Swift package that provides a minimal implementation of Zotero translators for iOS and macOS applications.

## Features

- Run Zotero translators in WKWebView
- Support for Safari Share Extension
- Modular JavaScript runtime
- Easy integration with existing apps

## Requirements

- iOS 14.0+ / macOS 11.0+
- Xcode 13.0+
- Swift 5.5+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/BEZoteroTranslators.git", from: "1.0.0")
]
```

## Usage

### Basic Usage

```swift
import BEZoteroTranslators

class YourViewController: UIViewController, ZoteroWebViewDelegate {
    private var zoteroWebView: ZoteroWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create and configure ZoteroWebView
        zoteroWebView = ZoteroWebView(frame: .zero, configuration: WKWebViewConfiguration())
        zoteroWebView.zoteroDelegate = self
        view.addSubview(zoteroWebView)
        
        // Load a translator
        if let translatorCode = loadTranslatorCode() {
            zoteroWebView.loadTranslator(translatorCode)
        }
    }
    
    // MARK: - ZoteroWebViewDelegate
    
    func zoteroWebView(_ webView: ZoteroWebView, didDetectType type: String) {
        print("Detected type: \(type)")
    }
    
    func zoteroWebView(_ webView: ZoteroWebView, didScrapeItems items: [[String: Any]]) {
        print("Scraped items: \(items)")
    }
    
    func zoteroWebView(_ webView: ZoteroWebView, didFailWithError error: Error) {
        print("Error: \(error.localizedDescription)")
    }
}
```

### Safari Share Extension

```swift
import BEZoteroTranslators

class ShareViewController: UIViewController, ZoteroWebViewDelegate {
    private var zoteroWebView: ZoteroWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create and configure ZoteroWebView
        zoteroWebView = ZoteroWebView(frame: .zero, configuration: WKWebViewConfiguration())
        zoteroWebView.zoteroDelegate = self
        view.addSubview(zoteroWebView)
        
        // Load the page from the share extension
        if let url = extensionContext?.inputItems.first as? NSExtensionItem,
           let itemProvider = url.attachments?.first {
            itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (url, error) in
                if let url = url as? URL {
                    DispatchQueue.main.async {
                        self?.loadPage(url: url)
                    }
                }
            }
        }
    }
}
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Zotero](https://www.zotero.org/) for their translator system
- [Zotero Translators](https://github.com/zotero/translators) for the translator code 