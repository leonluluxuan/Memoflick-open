//
//  PhotoWallWidgetBundle.swift
//  PhotoWallWidget
//
//  Created by leonlu on 2025/12/30.
//

import WidgetKit
import SwiftUI

@main
struct PhotoWallWidgetBundle: WidgetBundle {
    var body: some Widget {
        PhotoWallWidget()
        if #available(iOS 18.0, *) {
            PhotoWallWidgetControl()
        }
    }
}
