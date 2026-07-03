//
//  ministry_schedulerApp.swift
//  ministry-scheduler
//
//  Created by Flavio Corpa on 03/07/2026.
//

import SwiftUI
import SwiftData

@main
struct ministry_schedulerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DayEntry.self,
            MonthGoal.self,
            ServiceYearGoal.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
