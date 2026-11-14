import SwiftUI
import PaveRateCore

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: palette.stackSpacing) {
                if model.archives.isEmpty {
                    Text("No saved days yet.")
                        .font(.title.weight(.bold))
                        .foregroundStyle(palette.text)
                    Text("New day writes this shift onto the phone before it clears the loads and the paved track. Nothing is thrown away.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.text)
                }
                ForEach(model.archives) { record in
                    NavigationLink {
                        ArchiveDetailView(record: record)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.job.siteName.isEmpty ? "This job" : record.job.siteName)
                                .font(.title2.weight(.bold))
                            Text(record.savedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.title3.weight(.semibold))
                            Text("\(FieldFormat.fixed(record.tonsPlaced, digits: 1)) tons · \(record.loads.count) loads · \(record.photoNotes.count) photos")
                                .font(.body.weight(.semibold))
                        }
                        .foregroundStyle(palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(palette.cardPadding)
                        .frame(minHeight: 96)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.border, lineWidth: palette.borderWidth))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this saved day so you can read it or send it again.")
                }
            }
            .padding(palette.pagePadding)
        }
        .fieldScroll()
        .navigationTitle("Saved days")
        .background(palette.background.ignoresSafeArea())
    }
}

struct ArchiveDetailView: View {
    let record: DayArchive

    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette
    @State private var confirmDelete = false

    var body: some View {
        let summary = model.summary(for: record)
        let images = NoteImageStore.labeledImages(notes: record.photoNotes, loads: record.loads)
        ScrollView {
            VStack(alignment: .leading, spacing: palette.stackSpacing) {
                Text(summary.plainText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .textSelection(.enabled)
                ForEach(images) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.caption)
                            .font(.headline.weight(.bold))
                        Image(uiImage: item.image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(item.caption)
                    }
                }
                ShareBar(summary: summary, images: images)
                Button("Delete this saved day") { confirmDelete = true }
                    .buttonStyle(FieldSecondaryButtonStyle(destructive: true))
                    .accessibilityHint("Removes this copy from the phone. Today is left alone.")
            }
            .padding(palette.pagePadding)
        }
        .fieldScroll()
        .navigationTitle("Saved day")
        .background(palette.background.ignoresSafeArea())
        .confirmationDialog("Delete this saved day?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.deleteArchive(record.id)
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Today's job is not touched.")
        }
    }
}

/// Days tab: close today (check the summary, add the note and photos, send it, save it),
/// then the saved days underneath. Settings lives here too, since it is set once.
struct DaysView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette
    @State private var noteText = ""
    @State private var confirmClose = false
    @State private var justClosed = false

    var body: some View {
        let summary = model.dailySummary()
        ScrollView {
            VStack(alignment: .leading, spacing: palette.stackSpacing) {
                if justClosed {
                    closedCard
                } else if model.todayHasRecord {
                    Text("Close today\(model.job.siteName.isEmpty ? "" : " on \(model.job.siteName)")")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Everything below is filled from today's loads. Fix anything, send it, then save the day.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(summary.lines.filter { !$0.isEmpty }.enumerated()), id: \.offset) { index, line in
                            if index > 0 {
                                Rectangle().fill(palette.border).frame(height: palette.borderWidth)
                            }
                            Text(line)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(palette.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, palette.cardPadding)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.border, lineWidth: palette.borderWidth))
                    BigNumberField(
                        label: "Note for the day",
                        hint: "Saved with the day. Optional.",
                        unit: "",
                        numeric: false,
                        placeholder: "What happened today",
                        text: $noteText
                    )
                    SectionLabel(text: "Photos")
                    PhotoNoteSection()
                    ShareBar(
                        summary: summary,
                        images: NoteImageStore.labeledImages(notes: model.photoNotes, loads: model.loads)
                    )
                    Button("Save today and start a new day") { confirmClose = true }
                        .buttonStyle(FieldPrimaryButtonStyle())
                        .accessibilityHint("Saves this shift on the phone, then clears loads, the paved track, photos, and the note.")
                } else {
                    Text("Nothing to close yet")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(palette.text)
                    Text("Close today appears once this shift has a load, a track, a photo, weather, or a note.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SectionLabel(text: model.archives.isEmpty ? "Saved days" : "Saved days · \(model.archives.count)")
                if model.archives.isEmpty {
                    Text("No saved days yet. Each day you close lands here, and nothing is thrown away.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(model.archives) { record in
                    NavigationLink {
                        ArchiveDetailView(record: record)
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.savedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.title3.weight(.bold))
                                Text(record.job.siteName.isEmpty ? "This job" : record.job.siteName)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(palette.muted)
                            }
                            Spacer()
                            Text("\(FieldFormat.fixed(record.tonsPlaced, digits: 1)) t")
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(palette.text)
                        .padding(palette.cardPadding)
                        .frame(minHeight: palette.minControl)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.border, lineWidth: palette.borderWidth))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this saved day so you can read it or send it again.")
                }
            }
            .padding(palette.pagePadding)
        }
        .fieldScroll()
        .navigationTitle("Days")
        .background(palette.background.ignoresSafeArea())
        .fieldKeyboardDone()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ScreenModeMenu()
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Settings")
            }
        }
        .onAppear { noteText = model.dayNote }
        .onChange(of: noteText) { _, newValue in
            if newValue != model.dayNote { model.dayNote = newValue }
        }
        .confirmationDialog("Save today and start a new day?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Save and start a new day", role: .destructive) {
                model.startNewDay()
                noteText = ""
                FieldHaptics.success()
                withAnimation { justClosed = true }
            }
            Button("Keep working", role: .cancel) {}
        } message: {
            Text("The shift is written to Saved days first. The plan, the width, and the mix stay.")
        }
    }

    private var closedCard: some View {
        VStack(alignment: .leading, spacing: palette.tightSpacing) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(palette.good)
                .accessibilityHidden(true)
            Text("Today is saved.")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(palette.text)
            Text("Tomorrow starts clean with the same job, width and mix. The saved day is below if you need to send it again.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button("Done") { withAnimation { justClosed = false } }
                .buttonStyle(FieldSecondaryButtonStyle())
        }
    }
}
