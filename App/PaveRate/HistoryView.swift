import SwiftUI
import PaveRateCore

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
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
                        .padding(16)
                        .frame(minHeight: 96)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this saved day so you can read it or send it again.")
                }
            }
            .padding(20)
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
            VStack(alignment: .leading, spacing: 16) {
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
                    .buttonStyle(FieldSecondaryButtonStyle())
                    .accessibilityHint("Removes this copy from the phone. Today is left alone.")
            }
            .padding(20)
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
