import Foundation

/// Translator types (matching Zotero's bit flag system)
enum TranslatorType: Int, CaseIterable {
    case `import` = 1    // 2^0 = 1
    case export = 2      // 2^1 = 2  
    case web = 4         // 2^2 = 4
    case search = 8      // 2^3 = 8
    
    public var description: String {
        switch self {
        case .import: return "Import"
        case .export: return "Export"
        case .web: return "Web"
        case .search: return "Search"
        }
    }
    
    /// Get all types from a combined type value (e.g., 12 = Web + Search)
    public static func types(from combinedType: Int) -> [TranslatorType] {
        return allCases.filter { combinedType & $0.rawValue != 0 }
    }
    
    /// Get description for a combined type value
    public static func description(for combinedType: Int) -> String {
        let types = self.types(from: combinedType)
        return types.map { $0.description }.joined(separator: " + ")
    }
}
