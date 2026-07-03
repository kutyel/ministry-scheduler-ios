//
//  Item.swift
//  ministry-scheduler
//
//  Created by Flavio Corpa on 03/07/2026.
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
