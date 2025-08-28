//
//  AttachmentDownloader.swift
//  BEZoteroTranslators
//
//  Created based on ZShare
//

import Foundation

/// Handles downloading of attachments (PDFs, images, documents, etc.)
/// This is a simplified version of ZShare's AttachmentDownloader
public class AttachmentDownloader {
    
    // MARK: - Properties
    
    private let session: URLSession
    
    // MARK: - Initialization
    
    public init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Public API
    
    /// Download an attachment from a URL
    /// - Parameters:
    ///   - url: The URL to download from
    ///   - cookies: Optional cookies string for authentication
    ///   - userAgent: Optional user agent string
    ///   - referrer: Optional referrer string
    ///   - attachmentsFolderURL: Optional folder URL for saving attachments
    ///   - preferredFilename: Optional preferred filename (if not provided, uses URL's last path component)
    /// - Returns: URL of the downloaded file
    /// - Throws: AttachmentDownloaderError if download fails
    public func downloadAttachment(
        from url: URL,
        cookies: String? = nil,
        userAgent: String? = nil,
        referrer: String? = nil,
        attachmentsFolderURL: URL? = nil,
        preferredFilename: String? = nil
    ) async throws -> URL {
        
        var request = URLRequest(url: url)
        
        // Set headers
        if let cookies = cookies, !cookies.isEmpty {
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
        }
        if let userAgent = userAgent, !userAgent.isEmpty {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        if let referrer = referrer, !referrer.isEmpty {
            request.setValue(referrer, forHTTPHeaderField: "Referer")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AttachmentDownloaderError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AttachmentDownloaderError.httpError(httpResponse.statusCode)
        }
        
        // Determine content type
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream"
        
        // Create file URL - use attachments folder if provided, otherwise temporary directory
        let baseURL = attachmentsFolderURL ?? FileManager.default.temporaryDirectory
        
        // Generate filename: use preferred filename or URL's last path component
        let fileName: String
        if let preferredFilename = preferredFilename {
            fileName = preferredFilename
        } else {
            // Use URL's last path component as filename
            let urlFilename = url.lastPathComponent
            if !urlFilename.isEmpty && urlFilename != "/" {
                fileName = urlFilename
            } else {
                // Fallback to UUID if URL doesn't have a meaningful filename
                fileName = UUID().uuidString
            }
        }
        
        // Ensure filename has proper extension
        let fileExtension = extensionForContentType(contentType)
        let finalFileName: String
        if fileName.hasSuffix(".\(fileExtension)") {
            finalFileName = fileName
        } else {
            finalFileName = "\(fileName).\(fileExtension)"
        }
        
        let fileURL = baseURL.appendingPathComponent(finalFileName)
        
        // Ensure the directory exists
        if let attachmentsFolderURL = attachmentsFolderURL {
            try FileManager.default.createDirectory(at: attachmentsFolderURL, withIntermediateDirectories: true)
        }
        
        try data.write(to: fileURL)
        
        print("AttachmentDownloader: Downloaded attachment to: \(fileURL.path)")
        return fileURL
    }
    
    // MARK: - Private Methods
    
    /// Get file extension for a given content type
    private func extensionForContentType(_ contentType: String) -> String {
        switch contentType.lowercased() {
        case let type where type.contains("pdf"):
            return "pdf"
        case let type where type.contains("image/jpeg") || type.contains("image/jpg"):
            return "jpg"
        case let type where type.contains("image/png"):
            return "png"
        case let type where type.contains("image/gif"):
            return "gif"
        case let type where type.contains("text/html"):
            return "html"
        case let type where type.contains("text/plain"):
            return "txt"
        case let type where type.contains("application/json"):
            return "json"
        case let type where type.contains("application/xml"):
            return "xml"
        default:
            return "bin"
        }
    }
}

// MARK: - Errors

public enum AttachmentDownloaderError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case noData
    case fileSystemError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid HTTP response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noData:
            return "No data received"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        }
    }
}
