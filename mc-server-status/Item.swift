//
//  Item.swift
//  mc-server-status
//
//  Created by Aaron212 on 2025-07-11.
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
