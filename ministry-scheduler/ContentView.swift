//
//  ContentView.swift
//  ministry-scheduler
//
//  Created by Flavio Corpa on 03/07/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = DemoData.tab ?? "calendar"

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Calendar", systemImage: "calendar", value: "calendar") {
                CalendarTabView()
            }
            Tab("Year", systemImage: "chart.bar.fill", value: "year") {
                YearTabView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DayEntry.self, MonthGoal.self, ServiceYearGoal.self], inMemory: true)
}
