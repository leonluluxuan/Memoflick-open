//
//  memoflickApp.swift
//  memoflick
//
//  Created by leonlu on 2025/11/3.
//

import SwiftUI

@main
struct memoflickApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(iOS 17.0, *) {
                ContentView()
            } else {
                Text(Localization.text(.appRequiresIOS17))
                    .padding()
            }
        }
    }
}
