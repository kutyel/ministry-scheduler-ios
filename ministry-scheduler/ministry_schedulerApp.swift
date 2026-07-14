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

        // UI tests run against a throwaway in-memory store so they never
        // touch (or depend on) the real data. `--uitest-seed` fills the
        // current month with known entries the tests can assert against.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitest") {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: schema, configurations: [configuration])
            if arguments.contains("--uitest-seed") {
                let comps = Calendar.current.dateComponents([.year, .month], from: .now)
                let (y, m) = (comps.year!, comps.month!)
                let context = ModelContext(container)
                context.insert(DayEntry(year: y, month: m, day: 1, plannedMinutes: 120, actualMinutes: 90))
                context.insert(DayEntry(year: y, month: m, day: 2, plannedMinutes: 60, actualMinutes: 60))
                context.insert(DayEntry(year: y, month: m, day: 3, plannedMinutes: 240, actualMinutes: 240, category: .ldc))
                context.insert(DayEntry(year: y, month: m, day: 4, plannedMinutes: 60, actualMinutes: 30, category: .bethel))
                try? context.save()
            }
            return container
        }

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
