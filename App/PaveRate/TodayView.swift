import PhotosUI
import SwiftUI
import UIKit
import PaveRateCore

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette
    @State private var loadSheet: LoadSheetRequest?
    @State private var confirmNewDay = false
    @State private var noteText = ""
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: palette.stackSpacing) {
                boardGlance
                if model.plantCall.shouldCall {
                    StatusBanner(kind: .warn, message: model.plantCall.message, detail: "Tons ordered are on Feet Left.")
                }
                JobStrip(job: model.job)
                WeatherStrip(autoRefresh: true)
                runGlance
                loads
                SectionLabel(text: "Day note and photos")
                PhotoNoteSection()
                BigNumberField(
                    label: "Note for the day",
                    hint: "Saved with the day. Optional.",
                    unit: "",
                    numeric: false,
                    placeholder: "What happened today",
                    text: $noteText
                )
                ShareBar(
                    summary: model.dailySummary(),
                    images: NoteImageStore.labeledImages(notes: model.photoNotes, loads: model.loads)
                )
                newDay
            }
            .padding(palette.pagePadding)
            .padding(.bottom, palette.tightSpacing)
        }
        .fieldScroll()
        .navigationTitle("Today")
        .background(palette.background.ignoresSafeArea())
        .fieldKeyboardDone()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            dock
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ScreenModeMenu()
                NavigationLink {
                    HistoryView()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2.weight(.bold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(model.archives.isEmpty ? "Saved days" : "Saved days, \(model.archives.count)")
                .accessibilityHint("Opens shifts that were kept when a new day started.")
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2.weight(.bold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Settings")
            }
        }
        .onAppear { noteText = model.dayNote }
        .onChange(of: noteText) { _, newValue in
            if newValue != model.dayNote { model.dayNote = newValue }
        }
        .sheet(item: $loadSheet) { request in
            AddLoadSheet(existing: request.existing, startWithCamera: request.camera) { message in
                show(message)
            }
        }
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            withAnimation { toast = nil }
        }
        .confirmationDialog("Start a new day?", isPresented: $confirmNewDay, titleVisibility: .visible) {
            Button("Save this day, then clear it", role: .destructive) {
                model.startNewDay()
                noteText = ""
                FieldHaptics.tap()
                show("New day started. The last one is in Saved days.")
            }
            Button("Keep working", role: .cancel) {}
        } message: {
            Text("The shift is written to Saved days first. The plan, the width, and the mix stay.")
        }
    }

    private func show(_ message: String) {
        withAnimation { toast = message }
    }

    /// Add load stays under the thumb no matter how many loads are on the list.
    private var dock: some View {
        VStack(spacing: palette.tightSpacing) {
            if let toast {
                UndoToast(message: toast, canUndo: model.canUndo) {
                    model.undoLastChange()
                    noteText = model.dayNote
                    FieldHaptics.tap()
                    withAnimation { self.toast = nil }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: palette.tightSpacing) {
                Button("Add load") {
                    loadSheet = LoadSheetRequest(existing: nil, camera: false)
                }
                .buttonStyle(FieldPrimaryButtonStyle())
                .accessibilityHint("Logs a truck ticket.")
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        loadSheet = LoadSheetRequest(existing: nil, camera: true)
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title.weight(.bold))
                            .frame(width: palette.minControl, height: palette.minControl)
                            .foregroundStyle(palette.text)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                            .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.border, lineWidth: palette.borderWidth))
                    }
                    .buttonStyle(FieldPressStyle())
                    .accessibilityLabel("Add load from a ticket photo")
                }
            }
        }
        .padding(.horizontal, palette.pagePadding)
        .padding(.top, palette.tightSpacing)
        .padding(.bottom, palette.tightSpacing)
        .background(
            palette.background
                .overlay(alignment: .top) {
                    Rectangle().fill(palette.border).frame(height: palette.borderWidth)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var boardStatus: StatusKind? {
        switch model.currentBoard().status {
        case "pass": return .good
        case "warn": return .warn
        case "fail": return .bad
        default: return nil
        }
    }

    private var boardGlance: some View {
        let board = model.currentBoard()
        let ordered = parseField(model.inputs.feetOrdered)
        let placed = model.tonsPlacedToday ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            if let kind = boardStatus {
                StatusPill(kind: kind, text: board.headline)
            } else {
                Text(board.headline)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(board.feetLeftText)
                .outdoorFont(palette.heroPoints)
                .foregroundStyle(palette.text)
                .minimumScaleFactor(0.35)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let ordered, ordered > 0 {
                ProgressView(value: min(max(placed / ordered, 0), 1))
                    .tint(model.plantCall.shouldCall ? palette.warn : palette.good)
                    .scaleEffect(x: 1, y: 2.5, anchor: .center)
                    .padding(.vertical, 6)
                    .accessibilityLabel("Tons placed of the order")
                    .accessibilityValue("\(FieldFormat.fixed(placed, digits: 1)) of \(FieldFormat.groupedRound(ordered)) tons")
                Text("\(FieldFormat.fixed(placed, digits: 1)) of \(FieldFormat.groupedRound(ordered)) t placed · \(board.tonsText)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(board.tonsText)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(palette.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(palette.cardPadding)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.border, lineWidth: palette.borderWidth))
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
                    .outdoorFont(palette.fieldPoints)
                    .accessibilityLabel(model.settings.lengthHeadline(feet: run.lengthForCalcs))
                    .foregroundStyle(palette.text)
                    .minimumScaleFactor(0.35)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(run.plannedFeet > 0 ? "Plan \(run.stationPlanned) · \(FieldFormat.groupedRound(run.plannedAreaSqYd)) SY" : "Tracked \(run.stationPaved)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                if run.plannedFeet > 0 {
                    ProgressView(value: min(max(run.fraction, 0), 1))
                        .tint(run.overrun ? palette.warn : palette.good)
                        .accessibilityLabel(run.overrun ? "Tracked line is past the plan" : "Plan progress")
                        .accessibilityValue("\(FieldFormat.groupedRound(run.remainingFeet)) feet left")
                    Text(run.overrun ? "Tracked line is longer than the plan." : "\(FieldFormat.groupedRound(run.remainingFeet)) ft left on the plan")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.text)
                }
            }
        }
    }

    private var loads: some View {
        VStack(alignment: .leading, spacing: palette.tightSpacing) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: model.loads.isEmpty ? "Loads" : "Loads · \(model.loads.count)")
                Spacer()
                if !model.loads.isEmpty {
                    Text("\(FieldFormat.fixed(LoadLedger.tonsPlaced(model.loads), digits: 1)) t")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(palette.text)
                }
            }
            if model.loads.isEmpty {
                Text("No tickets yet. Tap Add load when the first truck dumps.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
            } else {
                Text("Newest first. Tap a load to change or delete it.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.muted)
                VStack(spacing: 0) {
                    ForEach(loadRows) { row in
                        if row.id != loadRows.first?.id {
                            Rectangle().fill(palette.border).frame(height: palette.borderWidth)
                        }
                        loadRow(index: row.number, load: row.load)
                    }
                }
                .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.border, lineWidth: palette.borderWidth))
                .clipShape(RoundedRectangle(cornerRadius: palette.cornerRadius))
            }
        }
    }

    /// Newest first, numbered in the order the trucks came.
    private var loadRows: [LoadRowItem] {
        model.loads.enumerated().reversed().map { LoadRowItem(number: $0.offset + 1, load: $0.element) }
    }

    private func loadRow(index: Int, load: LoadTicket) -> some View {
        let yield = LoadLedger.yield(tons: load.tons, coveredFeet: load.coveredFeet, job: model.job)
        let spec = yield.spec
        return Button {
            loadSheet = LoadSheetRequest(existing: load, camera: false)
        } label: {
            HStack(spacing: palette.tightSpacing) {
                Text("#\(index)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.muted)
                    .frame(minWidth: 36, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(FieldFormat.fixed(load.tons, digits: 2)) t")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    Text(rowDetail(load))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.muted)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let placed = yield.actualRateLbsSy, let spec {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(palette.status(spec.status.kind))
                            .frame(width: 14, height: 14)
                        Text(FieldFormat.groupedRound(placed))
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(palette.muted)
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, palette.cardPadding)
            .padding(.vertical, 8)
            .frame(minHeight: palette.minControl)
            .contentShape(Rectangle())
        }
        .buttonStyle(FieldPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(LoadLedger.line(index: index, load: load, job: model.job) + (spec.map { ". \($0.label)" } ?? ""))
        .accessibilityHint("Opens this load to change or delete it.")
    }

    private func rowDetail(_ load: LoadTicket) -> String {
        var parts: [String] = []
        if !load.truck.isEmpty { parts.append("Truck \(load.truck)") }
        if let feet = load.coveredFeet { parts.append("\(FieldFormat.groupedRound(feet)) ft") }
        if load.ticketPhotoFilename != nil { parts.append("photo") }
        return parts.isEmpty ? "Ticket" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var newDay: some View {
        if model.todayHasRecord {
            Button("New day") { confirmNewDay = true }
                .buttonStyle(FieldSecondaryButtonStyle())
                .accessibilityHint("Saves this shift on the phone, then clears loads, the paved track, photos, and the note.")
        } else {
            Text("New day appears once this shift has a load, a track, a photo, weather, or a note.")
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.muted)
        }
    }
}

struct LoadRowItem: Identifiable {
    let number: Int
    let load: LoadTicket
    var id: UUID { load.id }
}

struct LoadSheetRequest: Identifiable {
    let id = UUID()
    var existing: LoadTicket?
    var camera: Bool
}

struct AddLoadSheet: View {
    var existing: LoadTicket?
    /// Opens the camera first, from the camera button on Today.
    var startWithCamera: Bool = false
    /// Tells Today what changed so it can offer Undo.
    var onDone: (String) -> Void = { _ in }

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
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: palette.stackSpacing) {
                    BigNumberField(
                        label: "Truck",
                        hint: existing == nil && !truck.isEmpty ? "Filled from the last ticket. Change it if this is a different truck." : "Number on the side of the truck.",
                        unit: "",
                        numeric: false,
                        placeholder: "Number",
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
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                            .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.border, lineWidth: palette.borderWidth))
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
                            onDone("Load changed")
                        } else {
                            model.addLoad(
                                truck: truck,
                                tons: tonsValue,
                                coveredFeet: parseField(feet),
                                ticketPhotoFilename: photoName
                            )
                            onDone("Load \(model.loads.count) saved · \(FieldFormat.fixed(tonsValue, digits: 2)) t")
                        }
                        if let status = preview?.spec?.status {
                            FieldHaptics.status(status)
                        } else {
                            FieldHaptics.success()
                        }
                        dismiss()
                    }
                    .buttonStyle(FieldPrimaryButtonStyle())
                    if let existing {
                        Button("Delete this load", role: .destructive) {
                            confirmDelete = true
                        }
                        .buttonStyle(FieldSecondaryButtonStyle(destructive: true))
                        .accessibilityHint(existing.truck.isEmpty ? "Asks before removing this ticket." : "Asks before removing truck \(existing.truck).")
                        .confirmationDialog(deleteTitle(existing), isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Delete load", role: .destructive) {
                                model.deleteLoad(existing.id)
                                FieldHaptics.tap()
                                onDone(existing.truck.isEmpty ? "Load deleted" : "Truck \(existing.truck) deleted")
                                dismiss()
                            }
                            Button("Keep it", role: .cancel) {}
                        } message: {
                            Text("You can undo this from Today.")
                        }
                    }
                }
                .padding(palette.pagePadding)
            }
            .fieldScroll()
            .navigationTitle(existing == nil ? "Load" : "Edit load")
            .background(palette.background.ignoresSafeArea())
            .fieldKeyboardDone()
            .onAppear {
                prefill()
                if startWithCamera, existing == nil, UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                }
            }
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

    private func deleteTitle(_ load: LoadTicket) -> String {
        let tonsText = FieldFormat.fixed(load.tons, digits: 2)
        return load.truck.isEmpty ? "Delete this \(tonsText)-ton load?" : "Delete truck \(load.truck), \(tonsText) tons?"
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
