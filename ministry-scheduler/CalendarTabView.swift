//
//  CalendarTabView.swift
//  ministry-scheduler
//

import SwiftUI
import SwiftData

struct CalendarTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [DayEntry]
    @Query private var monthGoals: [MonthGoal]

    @State private var displayedYear: Int
    @State private var displayedMonth: Int
    @State private var selectedDay: Int?
    @State private var editingGoal = false

    private let calendar = Calendar.current

    init() {
        let comps = Calendar.current.dateComponents([.year, .month], from: .now)
        _displayedYear = State(initialValue: comps.year!)
        _displayedMonth = State(initialValue: comps.month!)
    }

    private var monthEntries: [DayEntry] {
        entries.filter { $0.year == displayedYear && $0.month == displayedMonth }
    }

    private var goalMinutes: Int {
        monthGoals.first { $0.year == displayedYear && $0.month == displayedMonth }?.goalMinutes
            ?? MonthGoal.defaultMinutes
    }

    private var plannedMinutes: Int { monthEntries.reduce(0) { $0 + $1.plannedMinutes } }
    private var spentMinutes: Int { monthEntries.reduce(0) { $0 + ($1.actualMinutes ?? 0) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryHeader
                    monthNavigator
                    calendarGrid
                    legend
                }
                .padding()
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") { goToToday() }
                }
            }
            .sheet(item: $selectedDay) { day in
                DayEditorSheet(
                    year: displayedYear,
                    month: displayedMonth,
                    day: day,
                    entry: monthEntries.first { $0.day == day }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $editingGoal) {
                GoalEditorSheet(
                    title: "Monthly Goal",
                    initialMinutes: goalMinutes,
                    onSave: saveGoal
                )
                .presentationDetents([.height(280)])
            }
        }
    }

    // MARK: - Header

    private var summaryHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(TimeFormat.hm(goalMinutes))
                        .font(.title2.bold())
                }
                Spacer()
                Button {
                    editingGoal = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                }
            }

            ProgressView(value: min(Double(spentMinutes), Double(goalMinutes)), total: Double(goalMinutes))
                .tint(spentMinutes >= goalMinutes ? .green : .accentColor)

            HStack {
                statBlock("Planned", TimeFormat.hm(plannedMinutes), .blue)
                Divider().frame(height: 32)
                statBlock("Spent", TimeFormat.hm(spentMinutes), .green)
                Divider().frame(height: 32)
                statBlock("Left", TimeFormat.hm(max(0, goalMinutes - spentMinutes)), .orange)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statBlock(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Month navigation

    private var monthNavigator: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal, 8)
    }

    private var monthTitle: String {
        let date = calendar.date(from: DateComponents(year: displayedYear, month: displayedMonth))!
        return date.formatted(.dateTime.month(.wide).year())
    }

    private func shiftMonth(_ delta: Int) {
        var m = displayedMonth + delta
        var y = displayedYear
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1; y += 1 }
        displayedMonth = m
        displayedYear = y
    }

    private func goToToday() {
        let comps = calendar.dateComponents([.year, .month], from: .now)
        displayedYear = comps.year!
        displayedMonth = comps.month!
    }

    // MARK: - Grid

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var calendarGrid: some View {
        let firstOfMonth = calendar.date(from: DateComponents(year: displayedYear, month: displayedMonth, day: 1))!
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)!.count
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let todayComps = calendar.dateComponents([.year, .month, .day], from: .now)

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            ForEach(0..<leadingBlanks, id: \.self) { _ in
                Color.clear.frame(height: 52)
            }
            ForEach(1...daysInMonth, id: \.self) { day in
                let isToday = todayComps.year == displayedYear
                    && todayComps.month == displayedMonth
                    && todayComps.day == day
                DayCell(
                    day: day,
                    entry: monthEntries.first { $0.day == day },
                    isToday: isToday
                )
                .onTapGesture { selectedDay = day }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendDot(.blue, "Planned")
            legendDot(.green, "Done")
            legendDot(.orange, "Under")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    // MARK: - Goal persistence

    private func saveGoal(_ minutes: Int) {
        if let existing = monthGoals.first(where: { $0.year == displayedYear && $0.month == displayedMonth }) {
            existing.goalMinutes = minutes
        } else {
            modelContext.insert(MonthGoal(year: displayedYear, month: displayedMonth, goalMinutes: minutes))
        }
    }
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Day cell

private struct DayCell: View {
    let day: Int
    let entry: DayEntry?
    let isToday: Bool

    private var status: (color: Color, label: String?) {
        guard let entry else { return (.clear, nil) }
        if let actual = entry.actualMinutes {
            let color: Color = actual >= entry.plannedMinutes ? .green : .orange
            return (color, TimeFormat.hm(actual))
        }
        if entry.plannedMinutes > 0 {
            return (.blue, TimeFormat.hm(entry.plannedMinutes))
        }
        return (.clear, nil)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.callout.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.accentColor : .primary)
            if let label = status.label {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(status.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(status.color == .clear ? Color(.systemGray6) : status.color.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.accentColor : .clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Day editor

private struct DayEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let year: Int
    let month: Int
    let day: Int
    let entry: DayEntry?

    @State private var plannedMinutes: Int
    @State private var confirmActual: Bool
    @State private var actualMinutes: Int

    init(year: Int, month: Int, day: Int, entry: DayEntry?) {
        self.year = year
        self.month = month
        self.day = day
        self.entry = entry
        _plannedMinutes = State(initialValue: entry?.plannedMinutes ?? 0)
        _confirmActual = State(initialValue: entry?.actualMinutes != nil)
        _actualMinutes = State(initialValue: entry?.actualMinutes ?? entry?.plannedMinutes ?? 0)
    }

    private var dateTitle: String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Planned time") {
                    DurationPicker(minutes: $plannedMinutes)
                }
                Section {
                    Toggle("Confirm time spent", isOn: $confirmActual.animation())
                    if confirmActual {
                        DurationPicker(minutes: $actualMinutes)
                    }
                } footer: {
                    if confirmActual {
                        Text(comparisonFooter)
                    }
                }
                if entry != nil {
                    Section {
                        Button("Remove entry", role: .destructive) {
                            if let entry { modelContext.delete(entry) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private var comparisonFooter: String {
        let diff = actualMinutes - plannedMinutes
        if diff == 0 { return "Exactly as planned." }
        if diff > 0 { return "\(TimeFormat.hm(diff)) more than planned." }
        return "\(TimeFormat.hm(-diff)) less than planned."
    }

    private func save() {
        let actual: Int? = confirmActual ? actualMinutes : nil
        if let entry {
            if plannedMinutes == 0 && actual == nil {
                modelContext.delete(entry)
            } else {
                entry.plannedMinutes = plannedMinutes
                entry.actualMinutes = actual
            }
        } else if plannedMinutes > 0 || actual != nil {
            modelContext.insert(DayEntry(
                year: year, month: month, day: day,
                plannedMinutes: plannedMinutes, actualMinutes: actual
            ))
        }
        dismiss()
    }
}

// MARK: - Shared pickers

struct DurationPicker: View {
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 0) {
            Picker("Hours", selection: Binding(
                get: { minutes / 60 },
                set: { minutes = $0 * 60 + minutes % 60 }
            )) {
                ForEach(0..<25, id: \.self) { h in
                    Text("\(h) h").tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Minutes", selection: Binding(
                get: { minutes % 60 },
                set: { minutes = (minutes / 60) * 60 + $0 }
            )) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                    Text("\(m) min").tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 120)
    }
}

struct GoalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialMinutes: Int
    let onSave: (Int) -> Void

    @State private var hoursText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Hours", text: $hoursText)
                            .keyboardType(.numberPad)
                            .font(.title2.bold())
                        Text("hours")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let hours = Int(hoursText), hours > 0 {
                            onSave(hours * 60)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                hoursText = String(initialMinutes / 60)
            }
        }
    }
}

#Preview {
    CalendarTabView()
        .modelContainer(for: [DayEntry.self, MonthGoal.self, ServiceYearGoal.self], inMemory: true)
}
