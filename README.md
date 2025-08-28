# BEZoteroTranslators

A Swift package for integrating Zotero translators into iOS/macOS applications. This package provides a modern, Swift-native interface for using Zotero's web translators to scrape bibliographic data from web pages with support for attachment downloading.

## Features

- Modern Swift async/await API
- Support for all Zotero translators
- Automatic translator registration and management
- Built-in attachment downloading for PDF files
- Thread-safe operation with @MainActor support
- Comprehensive error handling
- Progress reporting and item selection callbacks
- ZIPFoundation integration for file handling

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/BEZoteroTranslators.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. Go to File → Add Package Dependencies
2. Enter the repository URL
3. Select the version you want to use

## Usage

### Basic Usage

```swift
import BEZoteroTranslators
import WebKit

// Initialize ZoteroTranslators with attachment downloading enabled
let translatorsRootFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let tempFolderForAttachments = FileManager.default.temporaryDirectory.appendingPathComponent("TranslatorDownloadedAttachments")

let zoteroTranslators = try await ZoteroTranslators(
    translatorsRootFolder: translatorsRootFolder,
    enableAttachmentDownloading: true,
    attachmentsFolderURL: tempFolderForAttachments
)

// Set up callbacks for translation results
zoteroTranslators.onTranslationResult = { item in
    print("Translation completed with item: \(item)")
    // Handle the translated item
}

zoteroTranslators.onSelectItems = { items in
    print("Items available for selection: \(items)")
    // Present selection UI to user
}

zoteroTranslators.onTranslationProgress = { progress in
    print("Translation progress: \(progress)")
    // Update UI with progress
}

zoteroTranslators.onAttachmentDownloadProgress = { attachmentName, progress in
    print("Downloading \(attachmentName): \(Int(progress * 100))%")
    // Update download progress UI
}

// Process a web page
try await zoteroTranslators.processWeb(
    title: "Page Title",
    url: URL(string: "https://example.com")!,
    html: "<html>...</html>",
    cookies: "session=abc123",
    frames: [],
    userAgent: "Mozilla/5.0...",
    referrer: "https://google.com"
)
```

### Item Selection

When multiple items are found, the package can present a selection interface:

```swift
zoteroTranslators.onSelectItems = { items in
    // items is an array of tuples: [(key: String, value: String)]
    // Present these to the user for selection
    for (key, value) in items {
        print("\(key): \(value)")
    }
}

// When user selects an item, call:
zoteroTranslators.selectItems([("selected_key", "selected_value")])
```

### Attachment Downloading

The package can automatically download PDF attachments:

```swift
// Initialize with attachment downloading enabled
let zoteroTranslators = try await ZoteroTranslators(
    translatorsRootFolder: translatorsRootFolder,
    enableAttachmentDownloading: true,
    attachmentsFolderURL: attachmentsFolder
)

// Monitor download progress
zoteroTranslators.onAttachmentDownloadProgress = { attachmentName, progress in
    if progress >= 1.0 {
        print("Download completed: \(attachmentName)")
    } else if progress < 0 {
        print("Download failed: \(attachmentName)")
    } else {
        print("Downloading \(attachmentName): \(Int(progress * 100))%")
    }
}

// Downloaded attachments will be available in the specified folder
// The item dictionary will contain attachment information
```

### Error Handling

The package provides comprehensive error handling:

```swift
do {
    try await zoteroTranslators.processWeb(
        title: title,
        url: url,
        html: html,
        cookies: cookies,
        frames: frames,
        userAgent: userAgent,
        referrer: referrer
    )
} catch TranslationError.translatorNotFound {
    print("Translator not found for this page")
} catch TranslationError.translationFailed(let message) {
    print("Translation failed: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

### Integration with WebKit

For web applications, you can integrate with WKWebView:

```swift
// In your WKWebView delegate or navigation handler
webView.evaluateJavaScript("document.title") { title, error in
    webView.evaluateJavaScript("document.documentElement.outerHTML") { html, error in
        // Process the page with ZoteroTranslators
        Task {
            try await zoteroTranslators.processWeb(
                title: title as? String ?? "",
                url: webView.url ?? URL(string: "https://example.com")!,
                html: html as? String ?? "",
                cookies: "", // Extract from WKWebView if needed
                frames: [], // Extract from WKWebView if needed
                userAgent: webView.customUserAgent ?? "",
                referrer: ""
            )
        }
    }
}
```

## API Reference

### ZoteroTranslators

The main class for handling Zotero translations.

#### Initialization

```swift
init(translatorsRootFolder: URL, enableAttachmentDownloading: Bool = false, attachmentsFolderURL: URL? = nil) async throws
```

#### Callbacks

- `onTranslationResult: (([String: Any]) -> Void)?` - Called when translation completes
- `onSelectItems: (([(String, String)]) -> Void)?` - Called when item selection is needed
- `onTranslationProgress: ((String) -> Void)?` - Called with progress updates
- `onAttachmentDownloadProgress: ((String, Double) -> Void)?` - Called with download progress

#### Methods

- `processWeb(title:url:html:cookies:frames:userAgent:referrer:progressDelegate:) async throws` - Process a web page
- `selectItems(_ items: [(String, String)])` - Select items when multiple options are available

### TranslationError

Error types for translation failures:

- `translatorNotFound` - No suitable translator found
- `translationFailed(String)` - Translation failed with message
- `attachmentDownloadFailed(String)` - Attachment download failed
- `invalidURL` - Invalid URL provided

## Dependencies

- **ZIPFoundation**: Used for file handling and attachment downloading

## Testing

The package includes a comprehensive test suite. To run the tests:

1. Clone the repository
2. Open the project in Xcode
3. Select the test target
4. Press Cmd+U to run the tests

## Example Project

See the `BEZoteroTranslatorsAppDemo` project for a complete example of how to integrate the package into a SwiftUI macOS application with WebKit integration.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Zotero](https://www.zotero.org/) for their translator system
- [ZoteroJS](https://github.com/zotero/zotero) for the JavaScript runtime
- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) for file handling 