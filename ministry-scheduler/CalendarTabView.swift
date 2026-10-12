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
    @State private var showingReport = false

    private let calendar = Calendar.current

    init() {
        let comps = Calendar.current.dateComponents([.year, .month], from: .now)
        _displayedYear = State(initialValue: comps.year!)
        _displayedMonth = State(initialValue: DemoData.month ?? comps.month!)
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

    private var report: MonthlyReport {
        MonthlyReport(year: displayedYear, month: displayedMonth, entries: entries)
    }

    private var balance: MonthBalance {
        MonthBalance(year: displayedYear, month: displayedMonth, entries: entries, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryHeader
                    BalanceCard(balance: balance, goalMinutes: goalMinutes, calendar: calendar)
                    monthNavigator
                    calendarGrid
                    legend
                }
                .padding()
            }
            .navigationTitle("Schedule")
            .onAppear {
                if DemoData.opensReport { showingReport = true }
                if let day = DemoData.day { selectedDay = day }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingReport = true
                    } label: {
                        Label("Send report", systemImage: "paperplane")
                    }
                }
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
                .presentationDetents(DemoData.day != nil ? [.large] : [.medium, .large])
            }
            .sheet(isPresented: $editingGoal) {
                GoalEditorSheet(
                    title: "Monthly Goal",
                    initialMinutes: goalMinutes,
                    onSave: saveGoal
                )
                .presentationDetents([.height(280)])
            }
            .sheet(isPresented: $showingReport) {
                MonthReportSheet(report: report)
                    .presentationDetents(DemoData.opensReport ? [.large] : [.medium, .large])
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

            if report.creditedMinutes > 0 {
                Divider()
                HStack {
                    statBlock("Field service", TimeFormat.hm(report.fieldServiceMinutes), .green)
                    Divider().frame(height: 32)
                    statBlock("LDC", TimeFormat.hm(report.ldcMinutes), .purple)
                    Divider().frame(height: 32)
                    statBlock("Bethel", TimeFormat.hm(report.bethelMinutes), .purple)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statBlock(_ title: LocalizedStringKey, _ value: String, _ color: Color) -> some View {
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
        MonthGrid(year: displayedYear, month: displayedMonth, calendar: calendar).monthTitle
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

    private var calendarGrid: some View {
        let grid = MonthGrid(year: displayedYear, month: displayedMonth, calendar: calendar)
        let compensation = balance.compensation

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(grid.weekdaySymbols.indices, id: \.self) { index in
                Text(grid.weekdaySymbols[index])
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            ForEach(grid.cells) { cell in
                switch cell {
                case .blank:
                    Color.clear.frame(height: DayCell.height)
                case .day(let day):
                    DayCell(
                        day: day,
                        entry: monthEntries.first { $0.day == day },
                        isToday: grid.isToday(day: day),
                        extraMinutes: compensation[day]
                    )
                    .onTapGesture { selectedDay = day }
                }
            }
        }
        .id("\(displayedYear)-\(displayedMonth)")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendDot(.blue, "Planned")
            legendDot(.green, "Done")
            legendDot(.orange, "Under")
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: 10, height: 10)
                Text("Catch up")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendDot(_ color: Color, _ label: LocalizedStringKey) -> some View {
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
    /// Suggested extra minutes to recover time lost earlier in the month.
    var extraMinutes: Int?

    static let height: CGFloat = 60

    /// Confirmed minus planned time, only for confirmed days that drifted.
    private var deviation: Int? {
        guard let entry, let actual = entry.actualMinutes else { return nil }
        let diff = actual - entry.plannedMinutes
        return diff == 0 ? nil : diff
    }

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
                HStack(spacing: 2) {
                    if let entry, entry.category.isCredited {
                        Image(systemName: entry.category == .ldc ? "hammer.fill" : "building.2.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.purple)
                    }
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(status.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            if let deviation {
                Text(MonthBalance.signed(deviation))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(deviation > 0 ? .green : .orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else if let extraMinutes {
                Text(MonthBalance.signed(extraMinutes))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(status.color == .clear ? Color(.systemGray6) : status.color.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.accentColor : .clear, lineWidth: 1.5)
        )
        .overlay {
            if extraMinutes != nil && !isToday {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Balance

/// Shows at a glance how far the confirmed days drifted from the schedule,
/// where the projection lands against the goal, and when to catch up.
private struct BalanceCard: View {
    let balance: MonthBalance
    let goalMinutes: Int
    let calendar: Calendar

    private var hasData: Bool {
        balance.confirmedPlannedMinutes > 0 || balance.confirmedActualMinutes > 0
            || !balance.pendingDays.isEmpty
    }

    /// The whole month is before today, so nothing can be rescheduled.
    private var monthIsOver: Bool {
        let now = calendar.dateComponents([.year, .month], from: .now)
        return (balance.year, balance.month) < (now.year!, now.month!)
    }

    private var color: Color {
        switch balance.deviationMinutes {
        case ..<0: return .orange
        case 1...: return .green
        default: return .blue
        }
    }

    private var icon: String {
        switch balance.deviationMinutes {
        case ..<0: return "arrow.down.right.circle.fill"
        case 1...: return "arrow.up.right.circle.fill"
        default: return "checkmark.circle.fill"
        }
    }

    private var headline: String {
        let diff = balance.deviationMinutes
        if diff < 0 { return String(localized: "\(TimeFormat.hm(-diff)) behind schedule") }
        if diff > 0 { return String(localized: "\(TimeFormat.hm(diff)) ahead of schedule") }
        return String(localized: "On schedule")
    }

    private func dayName(_ day: Int) -> String {
        let date = calendar.date(from: DateComponents(year: balance.year, month: balance.month, day: day))!
        return date.formatted(.dateTime.weekday(.wide).day())
    }

    private var advice: String {
        let diff = balance.deviationMinutes
        if diff > 0 {
            return String(localized: "You have \(TimeFormat.hm(diff)) of margin. You can do less on an upcoming day if you need to.")
        }
        if diff == 0 {
            return String(localized: "Your confirmed days match the plan.")
        }
        if monthIsOver {
            return String(localized: "This month ended \(TimeFormat.hm(-diff)) below the schedule.")
        }
        if let next = balance.compensation.keys.min() {
            let extra = TimeFormat.hm(balance.compensation[next]!)
            var text = String(localized: "To catch up, add the time shown in orange to the marked days. Next: \(dayName(next)), +\(extra).")
            if balance.uncompensatedMinutes > 0 {
                text += " " + String(localized: "\(TimeFormat.hm(balance.uncompensatedMinutes)) does not fit in your planned days. Plan it on a free day.")
            }
            return text
        }
        return String(localized: "No planned days left this month. Plan \(TimeFormat.hm(-diff)) more on a free day to catch up.")
    }

    var body: some View {
        if hasData {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.title)
                        .foregroundStyle(color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Balance vs. schedule")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(headline)
                            .font(.title3.bold())
                            .foregroundStyle(color)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("balanceHeadline")

                Text(advice)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)

                if !monthIsOver {
                    let projected = balance.projectedMinutes
                    Label(
                        String(localized: "Projected: \(TimeFormat.hm(projected)) of \(TimeFormat.hm(goalMinutes))"),
                        systemImage: projected >= goalMinutes ? "flag.checkered" : "flag"
                    )
                    .font(.footnote)
                    .foregroundStyle(projected >= goalMinutes ? .green : .secondary)
                }

                if !balance.pendingDays.isEmpty {
                    let days = balance.pendingDays.map { String($0) }
                        .formatted(.list(type: .and))
                    Label(
                        String(localized: "Not confirmed yet: \(days). Confirm them to keep the balance accurate."),
                        systemImage: "questionmark.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
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
    @State private var category: HourCategory

    init(year: Int, month: Int, day: Int, entry: DayEntry?) {
        self.year = year
        self.month = month
        self.day = day
        self.entry = entry
        _plannedMinutes = State(initialValue: entry?.plannedMinutes ?? 0)
        _confirmActual = State(initialValue: entry?.actualMinutes != nil)
        _actualMinutes = State(initialValue: entry?.actualMinutes ?? entry?.plannedMinutes ?? 0)
        _category = State(initialValue: entry?.category ?? .fieldService)
    }

    /// Binding for one credited-category toggle. LDC and Bethel are mutually
    /// exclusive: turning one on replaces the other, turning it off returns
    /// the day to regular field service time.
    private func creditedToggle(_ target: HourCategory) -> Binding<Bool> {
        Binding(
            get: { category == target },
            set: { category = $0 ? target : .fieldService }
        )
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
                Section {
                    Toggle("LDC", isOn: creditedToggle(.ldc))
                    Toggle("Bethel", isOn: creditedToggle(.bethel))
                } header: {
                    Text("Category")
                } footer: {
                    Text("LDC and Bethel time is reported separately as credited hours.")
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
            .onChange(of: confirmActual) { _, isOn in
                // Default the confirmed time to whatever is currently planned,
                // unless this day already has a recorded actual time.
                if isOn && entry?.actualMinutes == nil {
                    actualMinutes = plannedMinutes
                }
            }
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
        if diff == 0 { return String(localized: "Exactly as planned.") }
        if diff > 0 { return String(localized: "\(TimeFormat.hm(diff)) more than planned.") }
        return String(localized: "\(TimeFormat.hm(-diff)) less than planned.")
    }

    private func save() {
        let actual: Int? = confirmActual ? actualMinutes : nil
        if let entry {
            if plannedMinutes == 0 && actual == nil {
                modelContext.delete(entry)
            } else {
                entry.plannedMinutes = plannedMinutes
                entry.actualMinutes = actual
                entry.category = category
            }
        } else if plannedMinutes > 0 || actual != nil {
            modelContext.insert(DayEntry(
                year: year, month: month, day: day,
                plannedMinutes: plannedMinutes, actualMinutes: actual,
                category: category
            ))
        }
        dismiss()
    }
}

// MARK: - Month report

/// Month-end summary split into field service and credited (LDC/Bethel)
/// hours, ready to send to Hourglass or any other reporting app.
private struct MonthReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let report: MonthlyReport

    var body: some View {
        NavigationStack {
            Form {
                Section("Hours") {
                    LabeledContent("Field service", value: TimeFormat.hm(report.fieldServiceMinutes))
                }
                Section {
                    LabeledContent("LDC", value: TimeFormat.hm(report.ldcMinutes))
                    LabeledContent("Bethel", value: TimeFormat.hm(report.bethelMinutes))
                    LabeledContent("Total credited", value: TimeFormat.hm(report.creditedMinutes))
                        .fontWeight(.semibold)
                } header: {
                    Text("Credited hours")
                } footer: {
                    Text("Credited time is sent to Hourglass automatically, labelled in the report remarks.")
                }
                Section {
                    Button {
                        HourglassIntegration.submit(report)
                    } label: {
                        Label("Send to Hourglass", systemImage: "hourglass")
                    }
                    ShareLink(item: report.reportText) {
                        Label("Share report…", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        UIPasteboard.general.string = report.reportText
                    } label: {
                        Label("Copy report", systemImage: "doc.on.doc")
                    }
                } footer: {
                    Text("Sending opens Hourglass with the report form pre-filled; credited time is included in the remarks. Sharing works with any other reporting app on this phone.")
                }
            }
            .navigationTitle(report.monthName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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

    let title: LocalizedStringKey
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
