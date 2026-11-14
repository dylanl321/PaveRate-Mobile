import SwiftUI
import UIKit
import PhotosUI
import PaveRateCore

enum NoteImageStore {
    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.72) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        let url = directory().appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: directory(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func image(named filename: String) -> UIImage? {
        let url = directory().appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func delete(_ filename: String) {
        let url = directory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    static func labeledImages(notes: [PhotoNote], loads: [LoadTicket]) -> [LabeledImage] {
        var images: [LabeledImage] = []
        for (index, note) in notes.enumerated() {
            if let image = image(named: note.imageFilename) {
                images.append(LabeledImage(caption: note.line(index: index + 1), image: image))
            }
        }
        for (index, load) in loads.enumerated() {
            guard let name = load.ticketPhotoFilename, let image = image(named: name) else { continue }
            images.append(LabeledImage(caption: "Ticket \(index + 1) · \(load.truck)", image: image))
        }
        return images
    }

    private static func directory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("PaveRateNotes", isDirectory: true)
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct PhotoNoteSection: View {
    @Environment(AppModel.self) private var model
    @Environment(FieldLocation.self) private var location
    @Environment(\.fieldPalette) private var palette

    @State private var caption = ""
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Photos")
            if model.photoNotes.isEmpty {
                Text("No photos yet. A picture is pinned to the paved station, or the plan if you have not tracked.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
            }
            ForEach(Array(model.photoNotes.enumerated()), id: \.element.id) { index, note in
                VStack(alignment: .leading, spacing: 6) {
                    if let image = NoteImageStore.image(named: note.imageFilename) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipped()
                            .accessibilityLabel(note.line(index: index + 1))
                    }
                    Text(note.line(index: index + 1))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.text)
                    Button("Remove photo") {
                        model.deletePhoto(note.id)
                        FieldHaptics.tap()
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.bad)
                    .frame(minHeight: 44)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))
            }
            BigNumberField(label: "Photo caption", hint: "What the picture is. Optional.", unit: "", numeric: false, text: $caption)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take photo") { showCamera = true }
                    .buttonStyle(FieldPrimaryButtonStyle())
                    .accessibilityHint("Pins the picture to the current station.")
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Choose photo")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: palette.minControl)
                    .foregroundStyle(palette.text)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))
            }
            .accessibilityHint("Pins a picture already on the phone to the current station.")
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                store(image)
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    store(image)
                }
                pickerItem = nil
            }
        }
    }

    private func store(_ image: UIImage) {
        guard let name = NoteImageStore.save(image) else { return }
        model.addPhoto(
            caption: caption,
            filename: name,
            stationFeet: model.stationForANote(),
            coordinate: location.coordinate
        )
        caption = ""
        FieldHaptics.success()
    }
}
