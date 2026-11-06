//
//  FavoriteMetadata.swift
//  memoflick
//
//  Created by Codex on 2025/12/10.
//

import Foundation

struct FavoriteMetadata: Equatable {
    var caption: String?
    var categoryName: String

    func sanitized() -> FavoriteMetadata {
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCaption = (trimmedCaption?.isEmpty ?? true) ? nil : trimmedCaption
        let trimmedCategory = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCategory = trimmedCategory.isEmpty ? FavoriteCategoryStore.defaultCategoryName : trimmedCategory
        return FavoriteMetadata(caption: cleanedCaption, categoryName: cleanedCategory)
    }
}
