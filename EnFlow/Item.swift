//
//  Item.swift
//  EnFlow
//
//  Created by Orion Goodman on 6/11/25.
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
