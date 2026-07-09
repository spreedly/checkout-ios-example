//
//  ValidationParamReset.swift
//  SpreedlySDKExample
//
//  Resets shared validation parameters so toggles don't carry across screens.
//

import SpreedlyCore

enum ValidationParamReset {
    static func reset() {
        let spreedly = Spreedly.shared()
        spreedly.setParam(parameter: .allowBlankName, value: false)
        spreedly.setParam(parameter: .allowExpiredDate, value: false)
        spreedly.setParam(parameter: .allowBlankDate, value: false)
        spreedly.setParam(parameter: .allowInternationalZipCodes, value: true)
    }
}
