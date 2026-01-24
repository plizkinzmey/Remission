import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct DiagnosticsLogDetailsSheet: View {
    let entry: DiagnosticsLogEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    Text(jsonString)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: proxy.size.height)
                }
            }
            .navigationTitle(L10n.tr("diagnostics.raw.json"))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("generic.close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        #if os(iOS)
                            UIPasteboard.general.string = jsonString
                        #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(jsonString, forType: .string)
                        #endif
                    } label: {
                        Label(L10n.tr("diagnostics.copy.json"), systemImage: "doc.on.doc")
                    }
                }
            }
        }
        #if os(macOS)
            .frame(minWidth: 500, minHeight: 400)
        #endif
    }

    private var jsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entry),
            let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }
}
