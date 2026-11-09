// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

/// "Summary for the doctor": one screen to show in the surgery, and the same content as an A4 PDF.
struct DoctorSummaryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.showsProfiles) private var showsProfiles
    @FetchRequest(sortDescriptors: [SortDescriptor(\Profile.createdAt)]) private var profiles: FetchedResults<Profile>

    /// The profile chosen on Today or here, or everyone.
    private var shown: [Medication] { medications.of(profile: showsProfiles ? state.profileFilter : nil) }
    @FetchRequest(sortDescriptors: [SortDescriptor(\Medication.name)])
    private var medications: FetchedResults<Medication>
    // Observed so the summary updates when doses change.
    @FetchRequest(sortDescriptors: [SortDescriptor(\DoseEvent.scheduledAt)])
    private var events: FetchedResults<DoseEvent>
    @AppStorage(AppSettings.missedAfterMinutesKey) private var missedAfterMinutes = AppSettings.defaultMissedAfterMinutes

    @State private var days = 30
    @State private var pdfURL: URL?

    private var summary: DoctorSummary {
        _ = events.count
        var summary = DoctorSummaryBuilder.build(medications: shown, days: days,
                                                 grace: TimeInterval(missedAfterMinutes * 60))
        if showsProfiles, let id = state.profileFilter {
            summary.profileName = profiles.first { $0.id == id }?.name
        }
        return summary
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Period", selection: $days) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("summaryPeriod")

                DoctorSummaryContent(summary: summary)
            }
            .padding()
        }
        .navigationTitle(Text("Summary for the doctor"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let pdfURL {
                    ShareLink(item: pdfURL, preview: SharePreview(Text("Summary for the doctor"))) {
                        Label("Export PDF", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("exportSummaryPDF")
                }
            }
        }
        .task(id: "\(days)-\(events.count)-\(medications.count)") {
            pdfURL = SummaryPDF.write(summary)
        }
    }
}

/// The summary itself. Used on screen and rendered into the PDF, so both always match.
struct DoctorSummaryContent: View {
    let summary: DoctorSummary
    var forPrint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if forPrint {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "Vzato").font(.title.weight(.heavy)).foregroundStyle(Palette.taken)
                    Text("Summary for the doctor").font(.title2.weight(.semibold))
                }
            }
            if let name = summary.profileName {
                Text(name).font(.title3.weight(.bold))
            }
            HStack(spacing: 6) {
                Text(summary.start, format: .dateTime.day().month().year())
                Text(verbatim: "–")
                Text(summary.end, format: .dateTime.day().month().year())
            }
            .font(.headline)

            totals

            if summary.rows.isEmpty {
                Text("No medications in this period.").foregroundStyle(.secondary)
            }
            ForEach(summary.rows) { row in
                MedicationSummaryCard(row: row)
            }

            if !summary.missed.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Missed doses").font(.headline)
                    ForEach(summary.missed) { dose in
                        HStack {
                            Text(dose.scheduledAt, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
                                .monospacedDigit()
                            Text(verbatim: "·")
                            Text(dose.name)
                        }
                        .font(.subheadline)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Recorded by the patient in Vzato. Vzato is not a medical device; the records are the patient's own.")
                HStack(spacing: 4) {
                    Text("Created")
                    Text(summary.generatedAt, format: .dateTime.day().month().year().hour().minute())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var totals: some View {
        HStack(spacing: 18) {
            stat(Text("Taken"), value: Text(summary.totalTaken, format: .number), color: Palette.taken)
            stat(Text("Missed"), value: Text(summary.totalMissed, format: .number), color: Palette.missed)
            stat(Text("Skipped"), value: Text(summary.totalSkipped, format: .number), color: Palette.skipped)
            if let adherence = summary.adherence {
                stat(Text("Adherence"), value: Text(adherence, format: .percent.precision(.fractionLength(0))), color: .primary)
            }
        }
    }

    private func stat(_ label: Text, value: Text, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            value.font(.title2.weight(.bold)).foregroundStyle(color).monospacedDigit()
            label.font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct MedicationSummaryCard: View {
    let row: DoctorSummary.Row

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name).font(.headline)
                if !row.strength.isEmpty { Text(row.strength).foregroundStyle(.secondary) }
                Spacer()
                if let adherence = row.adherence {
                    Text(adherence, format: .percent.precision(.fractionLength(0)))
                        .font(.headline)
                        .monospacedDigit()
                }
            }
            Text(planText).font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text("Taken \(row.taken) of \(row.scheduled)")
                if row.missed > 0 { Text(verbatim: "·"); Text("missed \(row.missed)").foregroundStyle(Palette.missed) }
                if row.skipped > 0 { Text(verbatim: "·"); Text("skipped \(row.skipped)") }
                if row.extraDoses > 0 { Text(verbatim: "·"); Text("extra \(row.extraDoses)") }
            }
            .font(.subheadline)
            if let stock = row.stockText {
                HStack(spacing: 6) {
                    Text("At home \(stock)")
                    if let runOut = row.runOut {
                        Text(verbatim: "·")
                        Text("runs out \(runOut.formatted(.dateTime.day().month()))")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    /// "1 tablet · 8:00, 20:00 · every day · after a meal"
    private var planText: String {
        let calendar = Calendar.current
        let times = row.minutesOfDay.compactMap { minutes in
            calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date())?
                .formatted(date: .omitted, time: .shortened)
        }.joined(separator: ", ")
        let days = row.repeatText
        var parts = [row.amountPerDose]
        if !times.isEmpty { parts.append(times) }
        if !days.isEmpty { parts.append(days) }
        if row.mealRelation != .any { parts.append(String(localized: row.mealRelation.label)) }
        return parts.joined(separator: " · ")
    }
}

/// Renders the summary as an A4 PDF in the temporary folder, split over as many pages as needed.
@MainActor
enum SummaryPDF {
    static let pageSize = CGSize(width: 595, height: 842)   // A4 in points
    static let margin: CGFloat = 36

    static func write(_ summary: DoctorSummary) -> URL? {
        let content = DoctorSummaryContent(summary: summary, forPrint: true)
            .frame(width: pageSize.width - 2 * margin, alignment: .leading)
            .padding(margin)
            .frame(width: pageSize.width, alignment: .topLeading)
            .background(Color.white)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: pageSize.width, height: nil)

        let day = summary.generatedAt.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            String(localized: "Vzato summary \(day).pdf"))
        var written = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: pageSize)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            let pages = max(1, Int((size.height / pageSize.height).rounded(.up)))
            for page in 0..<pages {
                pdf.beginPDFPage(nil)
                // Content is drawn bottom-up; shift so page N shows the Nth slice from the top.
                pdf.translateBy(x: 0, y: -(size.height - pageSize.height * CGFloat(page + 1)))
                draw(pdf)
                pdf.endPDFPage()
            }
            pdf.closePDF()
            written = true
        }
        return written ? url : nil
    }
}
