//
//  storeMapApp.swift
//  storeMap
//
//  Created by Joshua Shabu on 8/25/26.
//

import SwiftUI
import FirebaseCore

@main
struct storeMapApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
