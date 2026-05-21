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

    @MainActor
    class ConfiguratorNSView: NSView {
        var isFixedSize: Bool = false {
            didSet {
                if let window = window {
                    configure?(window, isFixedSize)
                }
            }
        }
        var configure: ((NSWindow, Bool) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window = window {
                configure?(window, isFixedSize)
            }
        }
    }

    struct MacWindowConfigurator: NSViewRepresentable {
        let isFixedSize: Bool
        let configure: (NSWindow, Bool) -> Void

        init(isFixedSize: Bool, configure: @escaping (NSWindow, Bool) -> Void) {
            self.isFixedSize = isFixedSize
            self.configure = configure
        }

        init(configure: @escaping (NSWindow) -> Void) {
            self.isFixedSize = false
            self.configure = { window, _ in configure(window) }
        }

        func makeNSView(context: Context) -> ConfiguratorNSView {
            let view = ConfiguratorNSView()
            view.configure = configure
            view.isFixedSize = isFixedSize
            return view
        }

        func updateNSView(_ nsView: ConfiguratorNSView, context _: Context) {
            nsView.configure = configure
            if nsView.isFixedSize != isFixedSize {
                nsView.isFixedSize = isFixedSize
            } else if let window = nsView.window {
                configure(window, isFixedSize)
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
