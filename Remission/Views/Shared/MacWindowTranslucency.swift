import Foundation
import SwiftUI

#if os(macOS)
    import AppKit

    struct MacWindowBackdropView: NSViewRepresentable {
        var material: NSVisualEffectView.Material = .underWindowBackground
        var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
        var state: NSVisualEffectView.State = .followsWindowActiveState

        func makeNSView(context _: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = material
            view.blendingMode = blendingMode
            view.state = state
            return view
        }

        func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
            nsView.material = material
            nsView.blendingMode = blendingMode
            nsView.state = state
        }
    }

    struct MacWindowConfigurator: NSViewRepresentable {
        let configure: (NSWindow) -> Void

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async { [weak view] in
                guard let window = view?.window else { return }
                configure(window)
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context _: Context) {
            DispatchQueue.main.async { [weak nsView] in
                guard let window = nsView?.window else { return }
                configure(window)
            }
        }
    }

    extension View {
        @ViewBuilder
        func configureMacWindowForTranslucency() -> some View {
            let isUITesting = ProcessInfo.processInfo.environment["UI_TESTING"] == "1"
            if isUITesting {
                self
            } else {
                background(
                    MacWindowConfigurator { window in
                        window.isOpaque = false
                        window.backgroundColor = .clear
                        window.titlebarAppearsTransparent = true
                        window.isMovableByWindowBackground = true
                    }
                )
            }
        }
    }
#endif
