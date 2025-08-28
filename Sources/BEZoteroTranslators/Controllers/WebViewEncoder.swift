//
//  WebViewEncoder.swift
//  BEZoteroTranslators
//
//  Created based on Zotero iOS
//

import Foundation

struct WebViewEncoder {
    /// Encodes optional string for JavaScript, converting nil to "null"
    static func optionalToJs(_ value: String?) -> String {
        return value.flatMap({ "'" + $0 + "'" }) ?? "null"
    }

    /// Encodes data which needs to be sent to webView. All data that is passed to JS is Base64 encoded so that it can be sent as a simple String.
    static func encodeForJavascript(_ data: Data?) -> String {
        return data.flatMap({ "'" + $0.base64EncodedString(options: .endLineWithLineFeed) + "'" }) ?? "null"
    }

    /// Encodes as JSON payload so that it can be sent to webView.
    static func encodeAsJSONForJavascript(_ payload: Any) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            return self.encodeForJavascript(data)
        } catch {
            print("❌ WebViewEncoder: JSON serialization failed for payload type: \(type(of: payload))")
            print("❌ WebViewEncoder: JSON serialization error: \(error)")
            
            // Try to identify the problematic part
            if let dict = payload as? [String: Any] {
                print("❌ WebViewEncoder: Payload is a dictionary with \(dict.count) keys")
                for (key, value) in dict {
                    do {
                        _ = try JSONSerialization.data(withJSONObject: [key: value], options: [])
                    } catch {
                        print("❌ WebViewEncoder: Key '\(key)' with value type '\(type(of: value))' is not JSON serializable")
                    }
                }
            }
            
            // Return a safe fallback
            return "null"
        }
    }
}