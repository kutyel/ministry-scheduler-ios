//
//  ContentView.swift
//  ministry-scheduler
//
//  Created by Flavio Corpa on 03/07/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Calendar", systemImage: "calendar") {
                CalendarTabView()
            }
            Tab("Year", systemImage: "chart.bar.fill") {
                YearTabView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DayEntry.self, MonthGoal.self, ServiceYearGoal.self], inMemory: true)
}
