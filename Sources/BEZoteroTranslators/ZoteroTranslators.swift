//
//  ZoteroTranslators.swift
//  BEZoteroTranslators
//
//  Created based on ZShare
//

import Foundation
import WebKit

@MainActor
public final class ZoteroTranslators {
    // MARK: - Properties
    
    private let translatorManager: TranslatorManager
    private let translationHandler: TranslationWebViewHandler
    private let webView: WKWebView  // Strong reference to prevent deallocation
    
    // Callbacks for translation results
    public var onTranslationResult: (([String: Any]) -> Void)?
    public var onSelectItems: (([(String, String)]) -> Void)?
    public var onTranslationProgress: ((String) -> Void)?
    
    // Attachment downloading configuration
    private let attachmentDownloader: AttachmentDownloader?
    private let attachmentsFolderURL: URL?
    
    // Default MIME type for PDF attachments (same as ZShare)
    private static let defaultMimeType = "application/pdf"
    
    // MARK: - Initialization
    
    /// Initialize ZoteroTranslators with optional attachment downloading
    /// - Parameters:
    ///   - translatorsRootFolder: Root folder for translator files
    ///   - enableAttachmentDownloading: Whether to enable attachment downloading
    ///   - attachmentsFolderURL: Optional folder URL for saving attachments
    public init(translatorsRootFolder: URL, enableAttachmentDownloading: Bool = false, attachmentsFolderURL: URL? = nil) async throws {
        print("ZoteroTranslators: Initializing with translators folder: \(translatorsRootFolder.path) and attachmentsFolderURL: \(attachmentsFolderURL?.path ?? "not set")")
        
        // Initialize translator manager
        self.translatorManager = try await TranslatorManager(translatorsRootFolder: translatorsRootFolder)
        
        // Create web view for translation
        let webView = WKWebView()
        
        // Store strong reference to web view
        self.webView = webView
        
        // Initialize translation handler
        self.translationHandler = TranslationWebViewHandler(webView: webView, translatorManager: translatorManager)
        
        // Set up attachment downloading if enabled
        if enableAttachmentDownloading, let attachmentsFolderURL = attachmentsFolderURL {
            self.attachmentDownloader = AttachmentDownloader()
            self.attachmentsFolderURL = attachmentsFolderURL
        } else {
            self.attachmentDownloader = nil
            self.attachmentsFolderURL = nil
        }
        
        // Set up callbacks for translation events
        self.translationHandler.setCallbacks(
            onLoadedItems: { [weak self] data, cookies, userAgent, referrer in
                self?.handleLoadedItems(data: data, cookies: cookies, userAgent: userAgent, referrer: referrer)
            },
            onSelectItems: { [weak self] items in
                self?.handleSelectItems(items: items)
            },
            onProgress: { [weak self] progress in
                self?.handleProgress(progress: progress)
            },
            onError: { [weak self] error in
                self?.handleError(error: error)
            }
        )
        
        print("ZoteroTranslators: Initialization complete")
    }
    
    // MARK: - Public API
    
    /// Translation result that can be either items or a selection request
    public enum TranslationResult {
        case items([[String: Any]])
        case selectItems([(key: String, value: String)])
    }
    
    /// Process web page for translation using callbacks
    /// - Parameters:
    ///   - title: Page title
    ///   - url: Page URL
    ///   - html: HTML content
    ///   - cookies: Cookies string
    ///   - frames: Frame data
    ///   - userAgent: User agent string
    ///   - referrer: Referrer URL
    /// - Throws: TranslationError if translation fails
    @MainActor
    public func processWeb(
        title: String,
        url: URL,
        html: String,
        cookies: String,
        frames: [String],
        userAgent: String,
        referrer: String
    ) async throws {
        print("ExtensionViewModel: start translation")
        
        // Clean up attachments folder before starting new translation
        cleanupAttachmentsFolder()
        
        // Start translation - results will be communicated via callbacks
        do {
            try await self.translationHandler.translate(
                url: url,
                title: title,
                html: html,
                cookies: cookies,
                frames: frames,
                userAgent: userAgent,
                referrer: referrer
            )
            print("ExtensionViewModel: translation handler completed successfully")
        } catch {
            // Check if this is a non-critical error that we should ignore
            if let nsError = error as NSError?,
               nsError.domain == "WKErrorDomain" && nsError.code == 5 {
                // This is a WKErrorDomain Code=5 error - check if translation was successful
                // If we have received items, this is likely a cleanup error that we can ignore
                print("ExtensionViewModel: Non-critical WKErrorDomain Code=5 error detected - translation may have succeeded")
                // Don't throw the error, just log it and continue
                return
            }
            
            print("ExtensionViewModel: translation handler failed with critical error: \(error)")
            throw error
        }
        
        // Clean up attachments folder with delay to allow caller app to access files
        cleanupAttachmentsFolderWithDelay()
    }
    
    // MARK: - Private Methods
    
    /// Handle loaded items from translation
    private func handleLoadedItems(data: [[String: Any]], cookies: String?, userAgent: String?, referrer: String?) {
        print("ExtensionViewModel: webview action - loaded \(data.count) zotero items")
        print("ExtensionViewModel: data = \(data)")
        
        // Process items and handle attachments if enabled
        Task {
            await processItemsWithAttachments(data, cookies: cookies, userAgent: userAgent, referrer: referrer)
        }
    }
    
    /// Handle item selection requests
    private func handleSelectItems(items: [(String, String)]) {
        print("🔧 SELECT ITEM CASE REACHED - loaded \(items.count) list items")
        
        // Call the onSelectItems callback if set
        if let onSelectItems = self.onSelectItems {
            print("ZoteroTranslators: Calling onSelectItems callback with \(items.count) items")
            onSelectItems(items)
        } else {
            // Auto-select all items as fallback
            if !items.isEmpty {
                print("ZoteroTranslators: Auto-selecting all \(items.count) items (no callback set)")
                Task {
                    self.translationHandler.selectItems(items)
                }
            }
        }
    }
    
    /// Handle progress updates
    private func handleProgress(progress: String) {
        print("ZoteroTranslators: Progress: \(progress)")
        // Call the translation progress callback if set
        self.onTranslationProgress?(progress)
    }
    
    /// Handle errors
    private func handleError(error: TranslationWebViewHandler.Error) {
        print("ExtensionViewModel: web view error - \(error)")
    }
    
    /// Process items and handle attachment downloading if enabled
    @MainActor
    private func processItemsWithAttachments(_ data: [[String: Any]], cookies: String?, userAgent: String?, referrer: String?) async {
        // If attachment downloading is not enabled, just return all items
        guard let attachmentDownloader = self.attachmentDownloader,
              let attachmentsFolderURL = self.attachmentsFolderURL else {
            print("ExtensionViewModel: calling onTranslationResult with all \(data.count) items (no attachment downloading)")
            // Call onTranslationResult for each item
            for item in data {
                self.onTranslationResult?(item)
            }
            return
        }
        
        print("ExtensionViewModel: attachment downloading enabled, processing \(data.count) items")
        
        // Process all items and download their attachments
        for (index, item) in data.enumerated() {
            print("ExtensionViewModel: processing item \(index + 1) of \(data.count)")
            
            // Check if this item has attachments
            guard let attachments = item["attachments"] as? [[String: Any]] else {
                print("ExtensionViewModel: item \(index + 1) has no attachments, returning as-is")
                self.onTranslationResult?(item)
                continue
            }
            
            // Find PDF attachments
            let pdfAttachments = attachments.filter { attachment in
                guard let mimeType = attachment["mimeType"] as? String else { return false }
                return mimeType == Self.defaultMimeType
            }
            
            if pdfAttachments.isEmpty {
                print("ExtensionViewModel: item \(index + 1) has no PDF attachments, returning as-is")
                self.onTranslationResult?(item)
                continue
            }
            
            print("ExtensionViewModel: item \(index + 1) has \(pdfAttachments.count) PDF attachment(s)")
            
            // Download all PDF attachments for this item
            for (attachmentIndex, pdfAttachment) in pdfAttachments.enumerated() {
                guard let urlString = pdfAttachment["url"] as? String,
                      let url = URL(string: urlString) else {
                    print("ExtensionViewModel: item \(index + 1) attachment \(attachmentIndex + 1) has no valid URL")
                    continue
                }
                
                // Use URL's last path component as filename, fallback to attachment title or default
                let urlFilename = url.lastPathComponent
                let attachmentTitle = pdfAttachment["title"] as? String
                let attachmentName: String
                
                if !urlFilename.isEmpty && urlFilename != "/" {
                    attachmentName = urlFilename
                } else if let title = attachmentTitle, !title.isEmpty {
                    attachmentName = title
                } else {
                    attachmentName = "attachment_\(attachmentIndex + 1).pdf"
                }
                
                print("ExtensionViewModel: downloading PDF attachment '\(attachmentName)' from \(url)")
                
                // Report download start
                self.onTranslationProgress?("Downloading attachment '\(attachmentName)'... 0%")
                
                do {
                    let attachmentURL = try await attachmentDownloader.downloadAttachment(
                        from: url,
                        cookies: cookies,
                        userAgent: userAgent,
                        referrer: referrer,
                        attachmentsFolderURL: attachmentsFolderURL,
                        preferredFilename: attachmentName
                    )
                    
                    print("ExtensionViewModel: PDF attachment '\(attachmentName)' downloaded to \(attachmentURL.path)")
                    
                    // Report download completion
                    self.onTranslationProgress?("Downloaded attachment '\(attachmentName)' successfully")
                    
                    // No need to move file since it's already in the correct folder
                    print("ExtensionViewModel: attachment saved to \(attachmentURL.path)")
                    
                } catch {
                    print("ExtensionViewModel: failed to download PDF attachment '\(attachmentName)': \(error)")
                    // Report download failure
                    self.onTranslationProgress?("Failed to download attachment '\(attachmentName)': \(error.localizedDescription)")
                }
            }
            
            // Return the item unchanged - the caller app will find the files in the attachments folder
            print("ExtensionViewModel: returning item \(index + 1) (attachments downloaded to folder)")
            self.onTranslationResult?(item)
        }
        
        print("ExtensionViewModel: completed processing all \(data.count) items")
    }
    
    /// Select items in the translation handler
    public func selectItems(_ items: [(String, String)]) {
        translationHandler.selectItems(items)
    }
    
    // MARK: - Cleanup Methods
    
    /// Clean up the attachments folder by removing all files
    private nonisolated func cleanupAttachmentsFolder() {
        guard let attachmentsFolderURL = attachmentsFolderURL else { return }
        
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: attachmentsFolderURL.path) {
                let contents = try fileManager.contentsOfDirectory(at: attachmentsFolderURL, includingPropertiesForKeys: nil)
                for fileURL in contents {
                    try fileManager.removeItem(at: fileURL)
                }
                print("ZoteroTranslators: Cleaned up attachments folder, removed \(contents.count) files")
            }
        } catch {
            print("ZoteroTranslators: Error cleaning up attachments folder: \(error)")
        }
    }
    
    /// Clean up the attachments folder with a delay to allow caller app to access files
    private func cleanupAttachmentsFolderWithDelay() {
        Task {
            // Wait 5 seconds to allow caller app to access the files
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            
            await MainActor.run {
                self.cleanupAttachmentsFolder()
            }
        }
    }
    
    // MARK: - Deinitializer
    
    deinit {
        print("ZoteroTranslators: Deinitializing, cleaning up attachments folder")
        cleanupAttachmentsFolder()
    }
}
