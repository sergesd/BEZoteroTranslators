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

## Git Submodules

This package uses git submodules to include external Zotero translator code. The submodule structure is:

```
Sources/BEZoteroTranslators/Resources/TranslationEngine/
└── translation/
    └── translate/ (git submodule)
        ├── src/ (Zotero translator engine)
        ├── modules/
        │   └── utilities/ (git submodule)
        │       └── resource/
        │           └── schema/
        │               └── global/ (git submodule)
        └── example/ (sample translators)
```

### Managing Git Submodules

#### Initial Setup
When you first clone this repository, you need to initialize the submodules:

```bash
# Clone the repository
git clone https://github.com/yourusername/BEZoteroTranslators.git
cd BEZoteroTranslators

# Initialize and update all submodules
git submodule update --init --recursive
```

#### Updating Submodules
To get the latest versions of external translator code:

```bash
# Update all submodules to their latest versions
git submodule update --remote --recursive

# Or update specific submodules
git submodule update --remote Sources/BEZoteroTranslators/Resources/TranslationEngine/translation/translate
git submodule update --remote Sources/BEZoteroTranslators/Resources/TranslationEngine/translation/translate/modules/utilities
git submodule update --remote Sources/BEZoteroTranslators/Resources/TranslationEngine/translation/translate/modules/utilities/resource/schema/global
```

#### Committing Submodule Updates
After updating submodules, commit the changes:

```bash
# Add the updated submodule references
git add Sources/BEZoteroTranslators/Resources/TranslationEngine/translation/translate
git add Sources/BEZoteroTranslators/Resources/TranslationEngine/translation/translate/modules/utilities
git add Sources/BEZoteroTranslators/Resources/TranslationEngine/translation/translate/modules/utilities/resource/schema/global

# Commit with a descriptive message
git commit -m "Update Zotero translator submodules to latest versions"
```

#### Submodule Status
Check the status of all submodules:

```bash
# Show all submodules and their commit hashes
git submodule status --recursive

# Show which submodules have updates available
git submodule foreach git fetch
git submodule foreach git status
```

#### Troubleshooting Submodules
If you encounter submodule issues:

```bash
# Reset all submodules to their expected state
git submodule deinit -f .
git submodule update --init --recursive

# Or reset a specific submodule
git submodule deinit -f Sources/BEZoteroTranslators/Resources/TranslationEngine/translation/translate
git submodule update --init Sources/BEZoteroTranslators/Resources/TranslationEngine/translation/translate
```

### What Each Submodule Contains

- **`translate`**: Core Zotero translator engine with RDF parsing, HTTP handling, and translator framework
- **`utilities`**: Helper functions for date parsing, schema validation, and text processing
- **`zotero-schema`**: Zotero item type schemas and validation rules

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

// Monitor progress (including attachment downloads)
zoteroTranslators.onTranslationProgress = { progress in
    print("Progress: \(progress)")
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
- `onTranslationProgress: ((String) -> Void)?` - Called with progress updates (including attachment downloads)

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
