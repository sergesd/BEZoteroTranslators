//
//  Constants.swift
//  BEZoteroTranslators
//
//  Created by Serge on 03.06.2025.
//

import Foundation

// MARK: - Error Types

public enum ZoteroTranslatorsError: LocalizedError, Sendable {
    case jsEnvironmentInitializationFailed
    case libraryNotFound(String)
    case libraryLoadingFailed(String)
    case jsContextCreationFailed
    case turndownServiceCreationFailed
    case conversionFailed
    case emptyResult
    case invalidInput(String)
    case jsException(String)
    case bundleResourceMissing(String)
    case webViewInitializationFailed

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .jsEnvironmentInitializationFailed:
            "Failed to initialize JavaScript environment"
        case let .libraryNotFound(libraryName):
            "\(libraryName) library not found in bundle"
        case let .libraryLoadingFailed(details):
            "Failed to load JavaScript libraries: \(details)"
        case .jsContextCreationFailed:
            "Failed to create JavaScript context"
        case .turndownServiceCreationFailed:
            "Failed to create TurndownService instance"
        case .conversionFailed:
            "Failed to convert HTML to Markdown"
        case .emptyResult:
            "Conversion produced empty result"
        case let .invalidInput(details):
            "Invalid input provided: \(details)"
        case let .jsException(details):
            "JavaScript execution error: \(details)"
        case let .bundleResourceMissing(resource):
            "Required bundle resource missing: \(resource)"
        case .webViewInitializationFailed:
            "Failed to initialize WKWebView"
        }
    }
}
