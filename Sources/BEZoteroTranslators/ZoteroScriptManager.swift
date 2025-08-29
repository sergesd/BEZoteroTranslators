//
//  ZoteroScriptManager.swift
//  BEZoteroTranslators
//
//  Created by AI Assistant
//  Copyright © 2024 BEZoteroTranslators. All rights reserved.
//

import Foundation
import WebKit

/// Unified script manager that loads all Zotero runtime files including JSON data
/// Follows a simple approach: load all scripts and JSON files in the correct order
class ZoteroScriptManager {

    /// Core Zotero runtime scripts including JSON files
    private let coreScripts = [
        "translate/src/zotero.js",
        "translate/src/promise.js",
        "translate/modules/utilities/openurl.js",
        "translate/modules/utilities/date.js",
        "translate/modules/utilities/xregexp-all.js",
        "translate/modules/utilities/xregexp-unicode-zotero.js",
        "translate/modules/utilities/utilities.js",
        "translate/modules/utilities/utilities_item.js",
        "translate/modules/utilities/schema.js",
        "translate/modules/utilities/resource/zoteroTypeSchemaData.js",
        "translate/modules/utilities/cachedTypes.js",
        "translate/src/utilities_translate.js",
        "debug.js",
        "translate/src/http.js",
        "translate/src/translator.js",
        "translate/src/translators.js",
        "translate/src/repo.js",
        "translate/src/translation/translate.js",
        "translate/src/translation/sandboxManager.js",
        "translate/src/translation/translate_item.js",
        "translate/src/tlds.js",
        "translate/src/proxy.js",
        "translate/src/rdf/init.js",
        "translate/src/rdf/uri.js",
        "translate/src/rdf/term.js",
        "translate/src/rdf/identity.js",
        "translate/src/rdf/n3parser.js",
        "translate/src/rdf/rdfparser.js",
        "translate/src/rdf/serialize.js",
        "messaging.js",
        "http.js",
        "translators.js",
        "translate_item.js",
        "index.js"
    ]


    /// Create WKUserScripts from a list of filenames
    private func createScripts(from filenames: [String], subdirectory: String, scriptType: String) throws -> [WKUserScript] {
        return try filenames.compactMap { filename in
            // Try to find the script in the specified subdirectory
            if let url = Bundle.module.url(forResource: filename.replacingOccurrences(of: ".js", with: ""),
                                         withExtension: "js",
                                         subdirectory: subdirectory) {
                return try createScript(from: url, filename: filename, scriptType: scriptType)
            }
            
            // If not found in subdirectory, try to find it in the translation root
            if let url = Bundle.module.url(forResource: filename.replacingOccurrences(of: ".js", with: ""),
                                         withExtension: "js",
                                         subdirectory: "translation") {
                return try createScript(from: url, filename: filename, scriptType: scriptType)
            }
            
            print("⚠️ ZoteroScriptManager: Could not find \(scriptType) script: \(filename)")
            return nil
        }
    }

    private func loadSchemaAndDateFormats() throws -> WKUserScript {
        //"translate/modules/utilities/resource/schema/global/schema.json",
        //"translate/modules/utilities/resource/dateFormats.json"

        guard let url = Bundle.module.url(forResource: "schema", withExtension: "json", subdirectory: "Resources/translation/translate/modules/utilities/resource/schema/global"),
              let schemaData = try? Data(contentsOf: url) else {
            print("❌ ZoteroScriptManager: Could not load schema.json")
            throw ZoteroScriptError.scriptLoadFailed("Could not load schema.json")
        }
        
        let encodedSchema = WebViewEncoder.encodeForJavascript(schemaData)
        
        guard let url = Bundle.module.url(forResource: "dateFormats", withExtension: "json", subdirectory: "Resources/translation/translate/modules/utilities/resource"),
              let dateFormatData = try? Data(contentsOf: url) else {
            print("❌ ZoteroScriptManager: Could not load dateFormats.json")
            throw ZoteroScriptError.scriptLoadFailed("Could not load dateFormats.json")
        }
        
        let encodedDateFormats = WebViewEncoder.encodeForJavascript(dateFormatData)
        
        let scriptContent = "initSchemaAndDateFormats(\(encodedSchema), \(encodedDateFormats));"
        print("✅ ZoteroScriptManager: loadSchemaAndDateFormats")
        
        return WKUserScript(
            source: scriptContent,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }
    
    /// Create a single WKUserScript
    private func createScript(from url: URL, filename: String, scriptType: String) throws -> WKUserScript {
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
            print("✅ ZoteroScriptManager: Loaded \(scriptType) script: \(filename)")
        } catch {
            print("❌ ZoteroScriptManager: Failed to read \(scriptType) script \(filename): \(error)")
            throw ZoteroScriptError.scriptLoadFailed("Could not read \(scriptType) script \(filename): \(error.localizedDescription)")
        }

        return WKUserScript(
            source: content,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }

    /// Load all Zotero scripts into a WebView
    @MainActor
    public func loadScriptsIntoWebView(_ webView: WKWebView) throws {
        print("ZoteroScriptManager: Loading Zotero scripts into WebView...")

        let coreUserScripts = try createScripts(from: coreScripts, subdirectory: "Resources/translation", scriptType: "Core")
        for script in coreUserScripts {
            webView.configuration.userContentController.addUserScript(script)
        }

        let schemaAndDateFormatsScript = try loadSchemaAndDateFormats()
        webView.configuration.userContentController.addUserScript(schemaAndDateFormatsScript)

        print("ZoteroScriptManager: ✅ Successfully loaded \(coreUserScripts.count) scripts into WebView")
    }

    /// Remove all Zotero scripts from a WebView
    @MainActor
    public func removeScriptsFromWebView(_ webView: WKWebView) {
        print("ZoteroScriptManager: Removing all Zotero scripts from WebView...")
        webView.configuration.userContentController.removeAllUserScripts()
        print("ZoteroScriptManager: ✅ Removed all scripts from WebView")
    }
}

// MARK: - Errors

    enum ZoteroScriptError: Error, LocalizedError {
    case scriptLoadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .scriptLoadFailed(let message):
            return "ZoteroScriptManager: \(message)"
        }
    }
}
