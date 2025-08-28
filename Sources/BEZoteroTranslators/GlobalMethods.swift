//
//  GlobalMethods.swift
//  BEBarcodeScanner
//
//  Created by Serge on 14.05.2025.
//

import Foundation

func print(_ items: Any...) {
    #if DEBUG
        Swift.print(items[0])
    #endif
}
