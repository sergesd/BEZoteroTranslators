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
        let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
        return self.encodeForJavascript(data)
    }
}
