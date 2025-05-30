# BEZoteroTranslators

A Swift package for integrating Zotero translators into iOS/macOS applications. This package provides a modern, Swift-native interface for using Zotero's web translators to scrape bibliographic data from web pages.

## Features

- Modern Swift async/await API
- Support for all Zotero translators
- Built-in test case extraction and validation
- Automatic translator registration and management
- Thread-safe operation
- Comprehensive error handling

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.5+
- Xcode 13.0+

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
import WebKit

// Create a WKWebView
let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

// Create a ZoteroManager instance
let manager = ZoteroManager(webView: webView)

// Load the Zotero runtime
try await manager.loadZoteroRuntime()

// Register a translator
try await manager.loadTranslator(translatorCode)

// Scrape a webpage
let items = try await manager.scrapePage()
```

### Managing Translators

```swift
// Register a translator from a file
try TranslatorRegistry.shared.registerTranslatorFromFile(name: "My Translator", fileURL: translatorURL)

// Get a registered translator
if let translator = TranslatorRegistry.shared.getTranslator(name: "My Translator") {
    // Use the translator
    let testCases = try translator.extractTestCases()
}
```

### Error Handling

The package provides comprehensive error handling through Swift's native error handling system:

```swift
do {
    try await manager.loadZoteroRuntime()
    let items = try await manager.scrapePage()
} catch ZoteroError.runtimeLoadFailed {
    // Handle runtime loading failure
} catch ZoteroError.translatorLoadFailed {
    // Handle translator loading failure
} catch ZoteroError.scrapeFailed {
    // Handle scraping failure
} catch {
    // Handle other errors
}
```

## Testing

The package includes a comprehensive test suite that demonstrates how to use the API and validate translator functionality. To run the tests:

1. Clone the repository
2. Open the project in Xcode
3. Select the test target
4. Press Cmd+U to run the tests

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Zotero](https://www.zotero.org/) for their translator system
- [ZoteroJS](https://github.com/zotero/zotero) for the JavaScript runtime 