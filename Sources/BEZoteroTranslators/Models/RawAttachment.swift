//
//  RawAttachment.swift
//  BEZoteroTranslators
//
//  Created based on ZShare
//

import Foundation

/// Represents raw attachment data extracted from web pages or direct file URLs
/// This is the foundation for the attachment download system
public enum RawAttachment: Sendable {
    /// Direct file URL (e.g., PDF, image, document)
    /// Used when the shared URL points directly to a file
    case remoteFileUrl(
        url: URL, 
        contentType: String, 
        cookies: String, 
        userAgent: String, 
        referrer: String
    )
    
    /// Web page that needs translation
    /// Used when the shared URL points to a web page that contains metadata
    case web(
        title: String, 
        url: URL, 
        html: String, 
        cookies: String, 
        frames: [String], 
        userAgent: String, 
        referrer: String
    )
}

// MARK: - Convenience Extensions

extension RawAttachment {
    /// The URL associated with this attachment
    public var url: URL {
        switch self {
        case .remoteFileUrl(let url, _, _, _, _):
            return url
        case .web(_, let url, _, _, _, _, _):
            return url
        }
    }
    
    /// The cookies string for this attachment
    public var cookies: String {
        switch self {
        case .remoteFileUrl(_, _, let cookies, _, _):
            return cookies
        case .web(_, _, _, let cookies, _, _, _):
            return cookies
        }
    }
    
    /// The user agent string for this attachment
    public var userAgent: String {
        switch self {
        case .remoteFileUrl(_, _, _, let userAgent, _):
            return userAgent
        case .web(_, _, _, _, _, let userAgent, _):
            return userAgent
        }
    }
    
    /// The referrer string for this attachment
    public var referrer: String {
        switch self {
        case .remoteFileUrl(_, _, _, _, let referrer):
            return referrer
        case .web(_, _, _, _, _, _, let referrer):
            return referrer
        }
    }
    
    /// Whether this is a direct file URL
    public var isDirectFile: Bool {
        switch self {
        case .remoteFileUrl:
            return true
        case .web:
            return false
        }
    }
    
    /// The content type for direct file URLs
    public var contentType: String? {
        switch self {
        case .remoteFileUrl(_, let contentType, _, _, _):
            return contentType
        case .web:
            return nil
        }
    }
    
    /// The title for web pages
    public var title: String? {
        switch self {
        case .remoteFileUrl:
            return nil
        case .web(let title, _, _, _, _, _, _):
            return title
        }
    }
    
    /// The HTML content for web pages
    public var html: String? {
        switch self {
        case .remoteFileUrl:
            return nil
        case .web(_, _, let html, _, _, _, _):
            return html
        }
    }
    
    /// The frames content for web pages
    public var frames: [String]? {
        switch self {
        case .remoteFileUrl:
            return nil
        case .web(_, _, _, _, let frames, _, _):
            return frames
        }
    }
}