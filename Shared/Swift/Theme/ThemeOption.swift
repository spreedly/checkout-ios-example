//
//  ThemeOption.swift
//  SpreedlySDKExample
//
//  Shared theme-picker option used by the merchant demos (card checkout and
//  ACH bank-account checkout). Each option drives a preset SpreedlyTheme that
//  the demo screens pass into the SDK drop-ins.
//

import Foundation

enum ThemeOption: String, CaseIterable {
    case `default` = "Default"
    case blue = "Blue Theme"
    case green = "Green Theme"
    case purple = "Purple Theme"

    var displayName: String {
        return self.rawValue
    }
}
