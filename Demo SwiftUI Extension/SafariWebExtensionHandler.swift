//
//  SafariWebExtensionHandler.swift
//  Appnomix Extension
//

import AppnomixCommerce

class SafariWebExtensionHandler: AppnomixWebExtensionHandler {
    override var extensionVersion: String { "2.0.1" }

    // TODO: As part of the integration guide, the partner must replace this string
    override var appGroupName: String { "group.app.appnomix.demo-swiftui" }

    override init() {
        super.init()
        
    }
}
