import SwiftUI
import UIKit
import PaveRateCore

enum SummaryExport {
    static func items(for summary: FieldSummary) -> [Any] {
        var items: [Any] = [summary.plainText]
        let stamp = Int(Date().timeIntervalSince1970)
        if let image = png(for: summary) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("paverate-\(stamp).png")
            try? image.write(to: url)
            items.append(url)
        }
        let pdf = pdfData(for: summary)
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("paverate-\(stamp).pdf")
        if (try? pdf.write(to: pdfURL)) != nil {
            items.append(pdfURL)
        }
        return items
    }

    static func png(for summary: FieldSummary) -> Data? {
        let width = 640.0
        let pad = 28.0
        let titleFont = UIFont.systemFont(ofSize: 34, weight: .bold)
        let bodyFont = UIFont.systemFont(ofSize: 22, weight: .semibold)
        let body = summary.lines.joined(separator: "\n")
        let bodyBounds = (body as NSString).boundingRect(
            with: CGSize(width: width - pad * 2, height: 4000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: bodyFont],
            context: nil
        )
        let height = 96 + ceil(bodyBounds.height) + pad * 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor(red: 0.961, green: 0.659, blue: 0, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: 88))
            (summary.title as NSString).draw(
                in: CGRect(x: pad, y: 22, width: width - pad * 2, height: 50),
                withAttributes: [.font: titleFont, .foregroundColor: UIColor.black]
            )
            (body as NSString).draw(
                in: CGRect(x: pad, y: 112, width: width - pad * 2, height: bodyBounds.height + 8),
                withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
            )
        }
        return image.pngData()
    }

    static func pdfData(for summary: FieldSummary) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let lines = summary.plainText.components(separatedBy: "\n")
        return renderer.pdfData { context in
            var y = 48.0
            func newPage() {
                context.beginPage()
                y = 48
            }
            newPage()
            for (index, line) in lines.enumerated() {
                let used = index == 0 ? titleFont : font
                let height = max(22, (line as NSString).boundingRect(
                    with: CGSize(width: 516, height: 200),
                    options: [.usesLineFragmentOrigin],
                    attributes: [.font: used],
                    context: nil
                ).height + 6)
                if y + height > 750 {
                    newPage()
                }
                (line as NSString).draw(
                    in: CGRect(x: 48, y: y, width: 516, height: height),
                    withAttributes: [.font: used, .foregroundColor: UIColor.black]
                )
                y += height
            }
        }
    }
}

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ShareBar: View {
    let summary: FieldSummary

    @Environment(\.fieldPalette) private var palette
    @State private var payload: SharePayload?
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            Button("Share") {
                FieldHaptics.tap()
                payload = SharePayload(items: SummaryExport.items(for: summary))
            }
            .buttonStyle(FieldPrimaryButtonStyle())

            Button(copied ? "Copied" : "Copy text") {
                UIPasteboard.general.string = summary.plainText
                FieldHaptics.success()
                copied = true
            }
            .buttonStyle(FieldSecondaryButtonStyle())
        }
        .sheet(item: $payload) { payload in
            ActivityShare(items: payload.items)
        }
    }
}

struct ActivityShare: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
        guard let popover = controller.popoverPresentationController, popover.sourceView == nil else { return }
        popover.sourceView = controller.view
        popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
    }
}

enum FieldHaptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func failure() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func status(_ status: PlacementStatus) {
        switch status {
        case .pass:
            success()
        case .warn:
            warning()
        case .fail:
            failure()
        }
    }
}

struct FieldPrimaryButtonStyle: ButtonStyle {
    @Environment(\.fieldPalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: palette.minControl)
            .foregroundStyle(palette.accentText)
            .background(palette.accent, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))
    }
}

struct FieldSecondaryButtonStyle: ButtonStyle {
    @Environment(\.fieldPalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: palette.minControl)
            .foregroundStyle(palette.text)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))
    }
}
