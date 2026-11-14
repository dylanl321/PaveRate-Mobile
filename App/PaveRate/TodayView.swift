import PhotosUI
import SwiftUI
import UIKit
import PaveRateCore

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette
    @State private var addingLoad = false
    @State private var editing: LoadTicket?
    @State private var confirmNewDay = false
    @State private var noteText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                boardGlance
                JobStrip(job: model.job)
                WeatherStrip(autoRefresh: true)
                runGlance
                if model.plantCall.shouldCall {
                    StatusBanner(kind: .warn, message: model.plantCall.message, detail: "Tons ordered are on Feet Left.")
                }
                loads
                PhotoNoteSection()
                BigNumberField(
                    label: "Note for the day",
                    hint: "Saved with the day. Optional.",
                    unit: "",
                    numeric: false,
                    text: $noteText
                )
                ShareBar(
                    summary: model.dailySummary(),
                    images: NoteImageStore.labeledImages(notes: model.photoNotes, loads: model.loads)
                )
                NavigationLink {
                    HistoryView()
                } label: {
                    Text(model.archives.isEmpty ? "Saved days" : "Saved days · \(model.archives.count)")
                }
                .buttonStyle(FieldSecondaryButtonStyle())
                .accessibilityHint("Opens shifts that were kept when a new day started.")
                NavigationLink {
                    SettingsView()
                } label: {
                    Text("Settings")
                }
                .buttonStyle(FieldSecondaryButtonStyle())
                glareButton
                if model.canUndo {
                    Button("Undo") {
                        model.undoLastChange()
                        noteText = model.dayNote
                        FieldHaptics.tap()
                    }
                    .buttonStyle(FieldSecondaryButtonStyle())
                    .accessibilityHint("Puts back the last change on this phone.")
                }
            }
            .padding(20)
            .padding(.bottom, 12)
        }
        .fieldScroll()
        .fieldKeyboardDone()
        .navigationTitle("Today")
        .background(palette.background.ignoresSafeArea())
        .onAppear { noteText = model.dayNote }
        .onChange(of: noteText) { _, newValue in
            if newValue != model.dayNote { model.dayNote = newValue }
        }
        .sheet(isPresented: $addingLoad) {
            AddLoadSheet()
        }
        .sheet(item: $editing) { load in
            AddLoadSheet(existing: load)
        }
        .confirmationDialog("Start a new day?", isPresented: $confirmNewDay, titleVisibility: .visible) {
            Button("Save this day, then clear it", role: .destructive) {
                model.startNewDay()
                noteText = ""
                FieldHaptics.tap()
            }
            Button("Keep working", role: .cancel) {}
        } message: {
            Text("The shift is written to Saved days first. The plan, the width, and the mix stay.")
        }
    }

    private var boardGlance: some View {
        let board = model.currentBoard()
        return VStack(alignment: .leading, spacing: 4) {
            Text(board.headline)
                .font(.title.weight(.bold))
                .foregroundStyle(palette.text)
            Text(board.feetLeftText)
                .outdoorFont(palette.heroPoints)
                .foregroundStyle(palette.text)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            Text(board.tonsText)
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(board.headline). \(board.feetLeftText). \(board.tonsText)")
    }

    private var runGlance: some View {
        let run = model.runMeasure
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Run")
            if run.lengthForCalcs <= 0 {
                Text("No run yet. Draw it on the Map tab. The length lands here and in the calculators.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
            } else {
                Text(model.settings.lengthHeadline(feet: run.lengthForCalcs))
                    .outdoorFont(palette.heroPoints)
                    .accessibilityLabel(model.settings.lengthHeadline(feet: run.lengthForCalcs))
                    .foregroundStyle(palette.text)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(run.plannedFeet > 0 ? "Plan \(run.stationPlanned) · \(FieldFormat.groupedRound(run.plannedAreaSqYd)) SY" : "Tracked \(run.stationPaved)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
                if run.plannedFeet > 0 {
                    ProgressView(value: min(max(run.fraction, 0), 1))
                        .tint(run.overrun ? palette.warn : palette.good)
                    Text(run.overrun ? "Tracked line is longer than the plan." : "\(FieldFormat.groupedRound(run.remainingFeet)) ft left on the plan")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.text)
                }
            }
        }
    }

    private var loads: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Loads")
            if model.loads.isEmpty {
                Text("No tickets yet. Tons placed on Feet Left come from this list once you add one.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
            } else {
                Text("\(FieldFormat.fixed(LoadLedger.tonsPlaced(model.loads), digits: 2)) tons placed")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.text)
                ForEach(Array(model.loads.enumerated()), id: \.element.id) { index, load in
                    loadRow(index: index + 1, load: load)
                }
            }
            Button("Add load") {
                addingLoad = true
            }
            .buttonStyle(FieldPrimaryButtonStyle())
            if model.todayHasRecord {
                Button("New day") { confirmNewDay = true }
                    .buttonStyle(FieldSecondaryButtonStyle())
                    .accessibilityHint("Saves this shift on the phone, then clears loads, the paved track, photos, and the note.")
            } else {
                Text("New day appears once this shift has a load, a track, a photo, weather, or a note.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.text)
            }
        }
    }

    private func loadRow(index: Int, load: LoadTicket) -> some View {
        let yield = LoadLedger.yield(tons: load.tons, coveredFeet: load.coveredFeet, job: model.job)
        return VStack(alignment: .leading, spacing: 6) {
            Text(LoadLedger.line(index: index, load: load, job: model.job))
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.text)
            if let guidance = yield.spec?.guidance {
                Text(guidance)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.text)
            }
            Button("Edit load") { editing = load }
                .font(.headline.weight(.bold))
                .frame(minHeight: 44)
                .foregroundStyle(palette.text)
            Button("Remove load") {
                model.deleteLoad(load.id)
                FieldHaptics.tap()
            }
            .font(.headline.weight(.bold))
            .frame(minHeight: 44)
            .foregroundStyle(palette.bad)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))
    }

    private var glareButton: some View {
        Button(model.appearance == .glare ? "Sunlight" : "Glare mode") {
            model.appearance = model.appearance == .glare ? .sunlight : .glare
            FieldHaptics.tap()
        }
        .buttonStyle(FieldSecondaryButtonStyle())
    }
}

struct AddLoadSheet: View {
    var existing: LoadTicket?

    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var truck = ""
    @State private var tons = ""
    @State private var feet = ""
    @State private var photoName: String?
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var missingTons = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BigNumberField(
                        label: "Truck",
                        hint: existing == nil && !truck.isEmpty ? "Filled from the last ticket. Change it if this is a different truck." : "Number on the side of the truck.",
                        unit: "",
                        numeric: false,
                        text: $truck
                    )
                    BigNumberField(label: "Tons on the ticket", unit: "tons", text: $tons)
                    BigNumberField(label: "Feet this load covered", hint: "Optional. Leave blank if you only have the ticket.", unit: "ft", text: $feet)
                    if let photoName, let image = NoteImageStore.image(named: photoName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .accessibilityLabel("Ticket photo")
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Ticket photo") { showCamera = true }
                            .buttonStyle(FieldSecondaryButtonStyle())
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("Ticket photo from library")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: palette.minControl)
                            .foregroundStyle(palette.text)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))
                    }
                    if let yield = preview {
                        if let expected = yield.expectedFeet {
                            Text("Should reach \(FieldFormat.groupedRound(expected)) ft at \(FieldFormat.groupedRound(model.job.targetRateLbsSy)) lbs/SY.")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(palette.text)
                        }
                        if let spec = yield.spec {
                            StatusBanner(kind: spec.status.kind, message: spec.label, detail: spec.guidance)
                        }
                    }
                    if let call = projectedCall, call.shouldCall {
                        StatusBanner(kind: .warn, message: call.message)
                    }
                    if missingTons {
                        Text("Enter the tons from the ticket before saving.")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.bad)
                    }
                    Button(existing == nil ? "Save load" : "Save changes") {
                        guard let tonsValue = parseField(tons), tonsValue > 0 else {
                            missingTons = true
                            FieldHaptics.warning()
                            return
                        }
                        if var existing {
                            existing.truck = truck.trimmingCharacters(in: .whitespacesAndNewlines)
                            existing.tons = tonsValue
                            existing.coveredFeet = parseField(feet)
                            existing.ticketPhotoFilename = photoName
                            model.updateLoad(existing)
                        } else {
                            model.addLoad(
                                truck: truck,
                                tons: tonsValue,
                                coveredFeet: parseField(feet),
                                ticketPhotoFilename: photoName
                            )
                        }
                        if let status = preview?.spec?.status {
                            FieldHaptics.status(status)
                        } else {
                            FieldHaptics.success()
                        }
                        dismiss()
                    }
                    .buttonStyle(FieldPrimaryButtonStyle())
                }
                .padding(20)
            }
            .fieldScroll()
            .navigationTitle(existing == nil ? "Load" : "Edit load")
            .background(palette.background.ignoresSafeArea())
            .fieldKeyboardDone()
            .onAppear(perform: prefill)
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    photoName = NoteImageStore.save(image)
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        photoName = NoteImageStore.save(image)
                    }
                    pickerItem = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.title3.weight(.bold))
                }
            }
        }
    }

    private var preview: LoadYield? {
        guard let tonsValue = parseField(tons), tonsValue > 0 else { return nil }
        return LoadLedger.yield(tons: tonsValue, coveredFeet: parseField(feet), job: model.job)
    }

    private var projectedCall: PlantCall? {
        guard let tonsValue = parseField(tons), tonsValue > 0 else { return nil }
        let current = model.tonsPlacedToday ?? 0
        let withoutThis = existing.map { current - $0.tons } ?? current
        return PlantCallCheck.evaluate(
            orderedTons: parseField(model.inputs.feetOrdered),
            placedTons: withoutThis + tonsValue,
            thresholdTons: model.settings.plantCallTons
        )
    }

    private func prefill() {
        if let existing {
            truck = existing.truck
            tons = displayNumber(existing.tons)
            feet = existing.coveredFeet.map(displayNumber) ?? ""
            photoName = existing.ticketPhotoFilename
            return
        }
        if let last = model.loads.last {
            truck = last.truck
            tons = displayNumber(last.tons)
        }
    }
}
