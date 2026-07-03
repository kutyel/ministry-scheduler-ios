//
//  YearTabView.swift
//  ministry-scheduler
//

import SwiftUI
import SwiftData
import Charts

struct YearTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [DayEntry]
    @Query private var yearGoals: [ServiceYearGoal]

    @State private var startYear: Int
    @State private var editingGoal = false

    init() {
        _startYear = State(initialValue: ServiceYear.startYear(containing: .now))
    }

    private var goalMinutes: Int {
        yearGoals.first { $0.startYear == startYear }?.goalMinutes
            ?? ServiceYearGoal.defaultMinutes
    }

    private struct MonthData: Identifiable {
        let year: Int
        let month: Int
        let plannedMinutes: Int
        let spentMinutes: Int
        var id: String { "\(year)-\(month)" }
        var label: String {
            Calendar.current.shortMonthSymbols[month - 1]
        }
    }

    private var monthsData: [MonthData] {
        ServiceYear.months(startYear: startYear).map { ym in
            let monthEntries = entries.filter { $0.year == ym.year && $0.month == ym.month }
            return MonthData(
                year: ym.year,
                month: ym.month,
                plannedMinutes: monthEntries.reduce(0) { $0 + $1.plannedMinutes },
                spentMinutes: monthEntries.reduce(0) { $0 + ($1.actualMinutes ?? 0) }
            )
        }
    }

    private var totalPlanned: Int { monthsData.reduce(0) { $0 + $1.plannedMinutes } }
    private var totalSpent: Int { monthsData.reduce(0) { $0 + $1.spentMinutes } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryHeader
                    yearNavigator
                    chart
                }
                .padding()
            }
            .navigationTitle("Service Year")
            .sheet(isPresented: $editingGoal) {
                GoalEditorSheet(
                    title: "Yearly Goal",
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
                    Text("Yearly Goal")
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

            ProgressView(value: min(Double(totalSpent), Double(goalMinutes)), total: Double(goalMinutes))
                .tint(totalSpent >= goalMinutes ? .green : .accentColor)

            HStack {
                statBlock("Planned", TimeFormat.hm(totalPlanned), .blue)
                Divider().frame(height: 32)
                statBlock("Spent", TimeFormat.hm(totalSpent), .green)
                Divider().frame(height: 32)
                statBlock("Left", TimeFormat.hm(max(0, goalMinutes - totalSpent)), .orange)
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

    // MARK: - Year navigation

    private var yearNavigator: some View {
        HStack {
            Button { startYear -= 1 } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text("Sep \(String(startYear)) – Aug \(String(startYear + 1))")
                .font(.headline)
            Spacer()
            Button { startYear += 1 } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Chart

    private var averageMonthlyGoalHours: Double {
        TimeFormat.hours(goalMinutes) / 12.0
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planned vs. spent per month")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart {
                ForEach(monthsData) { m in
                    BarMark(
                        x: .value("Month", m.label),
                        y: .value("Hours", TimeFormat.hours(m.plannedMinutes))
                    )
                    .position(by: .value("Series", "Planned"))
                    .foregroundStyle(by: .value("Series", "Planned"))

                    BarMark(
                        x: .value("Month", m.label),
                        y: .value("Hours", TimeFormat.hours(m.spentMinutes))
                    )
                    .position(by: .value("Series", "Spent"))
                    .foregroundStyle(by: .value("Series", "Spent"))
                }

                RuleMark(y: .value("Monthly average", averageMonthlyGoalHours))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("avg \(averageMonthlyGoalHours, format: .number.precision(.fractionLength(0)))h/mo")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartForegroundStyleScale([
                "Planned": Color.blue.opacity(0.5),
                "Spent": Color.green,
            ])
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 8))
                }
            }
            .frame(height: 280)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Goal persistence

    private func saveGoal(_ minutes: Int) {
        if let existing = yearGoals.first(where: { $0.startYear == startYear }) {
            existing.goalMinutes = minutes
        } else {
            modelContext.insert(ServiceYearGoal(startYear: startYear, goalMinutes: minutes))
        }
    }
}

#Preview {
    YearTabView()
        .modelContainer(for: [DayEntry.self, MonthGoal.self, ServiceYearGoal.self], inMemory: true)
}
