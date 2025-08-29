import Foundation

/// Comprehensive error types for translation operations
public enum TranslationError: LocalizedError, Sendable {
    
    // MARK: - Initialization Errors
    
    case initializationFailed(String)
    case translatorManagerCreationFailed(String)
    case webViewCreationFailed(String)
    case attachmentDownloaderCreationFailed(String)
    
    // MARK: - Translator Errors
    
    case noTranslatorsFound(String)
    case translatorLoadingFailed(String)
    case translatorExecutionFailed(String)
    case dependencyResolutionFailed(String)
    case invalidTranslatorData(String)
    
    // MARK: - WebView Errors
    
    case webViewLoadFailed(String)
    case javascriptExecutionFailed(String)
    case webViewNavigationFailed(String)
    case webViewTimeout(String)
    
    // MARK: - Network Errors
    
    case networkRequestFailed(String)
    case downloadFailed(String)
    case invalidResponse(String)
    case timeout(String)
    
    // MARK: - File System Errors
    
    case fileSystemError(String)
    case attachmentSaveFailed(String)
    case cleanupFailed(String)
    case invalidFilePath(String)
    
    // MARK: - Data Processing Errors
    
    case dataExtractionFailed(String)
    case invalidDataFormat(String)
    case parsingFailed(String)
    case encodingFailed(String)
    
    // MARK: - Configuration Errors
    
    case invalidConfiguration(String)
    case missingRequiredParameter(String)
    case unsupportedOperation(String)
    
    // MARK: - Unknown Errors
    
    case unknown(String)
    
    // MARK: - LocalizedError Implementation
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let details):
            return "Initialization failed: \(details)"
        case .translatorManagerCreationFailed(let details):
            return "Translator manager creation failed: \(details)"
        case .webViewCreationFailed(let details):
            return "WebView creation failed: \(details)"
        case .attachmentDownloaderCreationFailed(let details):
            return "Attachment downloader creation failed: \(details)"
        case .noTranslatorsFound(let url):
            return "No translators found for URL: \(url)"
        case .translatorLoadingFailed(let details):
            return "Translator loading failed: \(details)"
        case .translatorExecutionFailed(let details):
            return "Translator execution failed: \(details)"
        case .dependencyResolutionFailed(let details):
            return "Dependency resolution failed: \(details)"
        case .invalidTranslatorData(let details):
            return "Invalid translator data: \(details)"
        case .webViewLoadFailed(let details):
            return "WebView load failed: \(details)"
        case .javascriptExecutionFailed(let details):
            return "JavaScript execution failed: \(details)"
        case .webViewNavigationFailed(let details):
            return "WebView navigation failed: \(details)"
        case .webViewTimeout(let details):
            return "WebView timeout: \(details)"
        case .networkRequestFailed(let details):
            return "Network request failed: \(details)"
        case .downloadFailed(let details):
            return "Download failed: \(details)"
        case .invalidResponse(let details):
            return "Invalid response: \(details)"
        case .timeout(let details):
            return "Timeout: \(details)"
        case .fileSystemError(let details):
            return "File system error: \(details)"
        case .attachmentSaveFailed(let details):
            return "Attachment save failed: \(details)"
        case .cleanupFailed(let details):
            return "Cleanup failed: \(details)"
        case .invalidFilePath(let details):
            return "Invalid file path: \(details)"
        case .dataExtractionFailed(let details):
            return "Data extraction failed: \(details)"
        case .invalidDataFormat(let details):
            return "Invalid data format: \(details)"
        case .parsingFailed(let details):
            return "Parsing failed: \(details)"
        case .encodingFailed(let details):
            return "Encoding failed: \(details)"
        case .invalidConfiguration(let details):
            return "Invalid configuration: \(details)"
        case .missingRequiredParameter(let details):
            return "Missing required parameter: \(details)"
        case .unsupportedOperation(let details):
            return "Unsupported operation: \(details)"
        case .unknown(let details):
            return "Unknown error: \(details)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .initializationFailed, .translatorManagerCreationFailed, .webViewCreationFailed, .attachmentDownloaderCreationFailed:
            return "System initialization error"
        case .noTranslatorsFound, .translatorLoadingFailed, .translatorExecutionFailed, .dependencyResolutionFailed, .invalidTranslatorData:
            return "Translator processing error"
        case .webViewLoadFailed, .javascriptExecutionFailed, .webViewNavigationFailed, .webViewTimeout:
            return "WebView operation error"
        case .networkRequestFailed, .downloadFailed, .invalidResponse, .timeout:
            return "Network operation error"
        case .fileSystemError, .attachmentSaveFailed, .cleanupFailed, .invalidFilePath:
            return "File system operation error"
        case .dataExtractionFailed, .invalidDataFormat, .parsingFailed, .encodingFailed:
            return "Data processing error"
        case .invalidConfiguration, .missingRequiredParameter, .unsupportedOperation:
            return "Configuration error"
        case .unknown:
            return "Unknown error"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .initializationFailed:
            return "Check system resources and try again"
        case .noTranslatorsFound:
            return "Verify that translators are properly installed and the URL is supported"
        case .translatorLoadingFailed:
            return "Check translator file integrity and permissions"
        case .webViewLoadFailed:
            return "Check network connectivity and URL accessibility"
        case .javascriptExecutionFailed:
            return "Try refreshing the page or using a different browser"
        case .networkRequestFailed:
            return "Check network connectivity and try again"
        case .downloadFailed:
            return "Check file permissions and available disk space"
        case .fileSystemError:
            return "Check file permissions and available disk space"
        case .dataExtractionFailed:
            return "The page content may not be compatible with available translators"
        case .invalidConfiguration:
            return "Check configuration settings and required parameters"
        default:
            return "Try again or contact support if the problem persists"
        }
    }
}

// MARK: - Error Context

public struct ErrorContext {
    public let url: URL?
    public let translatorLabel: String?
    public let timestamp: Date
    public let userAgent: String?
    public let additionalInfo: [String: Any]
    
    public init(
        url: URL? = nil,
        translatorLabel: String? = nil,
        userAgent: String? = nil,
        additionalInfo: [String: Any] = [:]
    ) {
        self.url = url
        self.translatorLabel = translatorLabel
        self.timestamp = Date()
        self.userAgent = userAgent
        self.additionalInfo = additionalInfo
    }
}

// MARK: - Error with Context

public struct TranslationErrorWithContext {
    public let error: TranslationError
    public let context: ErrorContext
    
    public init(_ error: TranslationError, context: ErrorContext) {
        self.error = error
        self.context = context
    }
    
    public var localizedDescription: String {
        var description = error.localizedDescription
        
        if let url = context.url {
            description += " (URL: \(url.absoluteString))"
        }
        
        if let translator = context.translatorLabel {
            description += " (Translator: \(translator))"
        }
        
        return description
    }
}
