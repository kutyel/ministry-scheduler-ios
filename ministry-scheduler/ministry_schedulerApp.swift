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

        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // The on-disk store predates the current schema and can't be
            // migrated (e.g. the Xcode template's Item store). Wipe it and
            // start fresh rather than crashing on every launch.
            let storeURL = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false).url
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
            do {
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
