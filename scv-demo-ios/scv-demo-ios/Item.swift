//
//  Item.swift
//  scv-demo-ios
//
//  Created by Visakha on 03/11/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
