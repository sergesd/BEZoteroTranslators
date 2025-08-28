import Foundation

/// Represents the result of a translation operation
public struct TranslationResult: Codable {
    /// The extracted items from the translation
    public let items: [[String: Any]]
    
    /// The detected item type (e.g., "journalArticle", "preprint")
    public let detectedType: String?
    
    /// The URL that was translated
    public let url: URL
    
    /// The timestamp when the translation was performed
    public let timestamp: Date
    
    /// The translator that was used
    public let translatorLabel: String?
    
    /// Any warnings or notes from the translation
    public let warnings: [String]
    
    /// Whether the translation was successful
    public var isSuccessful: Bool {
        !items.isEmpty
    }
    
    /// The number of items extracted
    public var itemCount: Int {
        items.count
    }
    
    public init(
        items: [[String: Any]],
        detectedType: String?,
        url: URL,
        translatorLabel: String? = nil,
        warnings: [String] = []
    ) {
        self.items = items
        self.detectedType = detectedType
        self.url = url
        self.timestamp = Date()
        self.translatorLabel = translatorLabel
        self.warnings = warnings
    }
    
    /// Creates a failed translation result
    public static func failed(url: URL, error: String) -> TranslationResult {
        return TranslationResult(
            items: [],
            detectedType: nil,
            url: url,
            warnings: [error]
        )
    }
    
    /// Creates a successful translation result
    public static func success(
        items: [[String: Any]],
        detectedType: String?,
        url: URL,
        translatorLabel: String?
    ) -> TranslationResult {
        return TranslationResult(
            items: items,
            detectedType: detectedType,
            url: url,
            translatorLabel: translatorLabel
        )
    }
}

// MARK: - Codable Implementation for [[String: Any]]
extension TranslationResult {
    private enum CodingKeys: String, CodingKey {
        case items, detectedType, url, timestamp, translatorLabel, warnings
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle [[String: Any]] encoding/decoding
        let itemsData = try container.decode(Data.self, forKey: .items)
        let itemsArray = try JSONSerialization.jsonObject(with: itemsData) as? [[String: Any]] ?? []
        
        self.items = itemsArray
        self.detectedType = try container.decodeIfPresent(String.self, forKey: .detectedType)
        self.url = try container.decode(URL.self, forKey: .url)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.translatorLabel = try container.decodeIfPresent(String.self, forKey: .translatorLabel)
        self.warnings = try container.decode([String].self, forKey: .warnings)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode [[String: Any]] as Data
        let itemsData = try JSONSerialization.data(withJSONObject: items)
        try container.encode(itemsData, forKey: .items)
        
        try container.encodeIfPresent(detectedType, forKey: .detectedType)
        try container.encode(url, forKey: .url)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(translatorLabel, forKey: .translatorLabel)
        try container.encode(warnings, forKey: .warnings)
    }
}

// MARK: - Custom Equality
extension TranslationResult {
    /// Custom equality check that compares relevant fields
    public func isEqual(to other: TranslationResult) -> Bool {
        return self.url == other.url &&
               self.detectedType == other.detectedType &&
               self.translatorLabel == other.translatorLabel &&
               self.warnings == other.warnings &&
               self.itemCount == other.itemCount &&
               self.isSuccessful == other.isSuccessful
    }
}
