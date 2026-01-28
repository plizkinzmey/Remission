import ComposableArchitecture
import SwiftUI
import Testing

@testable import Remission

@Suite("Shared View Coverage")
@MainActor
struct SharedViewCoverageTests {
    @Test
    func emptyPlaceholderViewRenders() {
        let view = EmptyPlaceholderView(
            systemImage: "tray",
            title: "Title",
            message: "Message"
        )
        _ = view.body
    }

    @Test
    func errorBannerViewRendersWithAndWithoutRetry() {
        let retry = ErrorBannerView(
            message: "Something failed",
            onRetry: {},
            onDismiss: {}
        )
        let noRetry = ErrorBannerView(
            message: "Something failed",
            onRetry: nil,
            onDismiss: {}
        )
        _ = retry.body
        _ = noRetry.body
    }

    @Test
    func keyboardHandlingExtensionsAreCallable() {
        _ = Text("Input").appKeyboardAvoiding()
        _ = Text("Input").appDismissKeyboardOnTap()
    }

    @Test
    func macWindowTranslucencyModifierIsCallable() {
        #if os(macOS)
            _ = Text("Window").configureMacWindowForTranslucency()
        #endif
    }

    @Test
    func transmissionTrustPromptViewRendersCertificateDetails() {
        let identity = TransmissionServerTrustIdentity(
            host: "example.com",
            port: 443,
            isSecure: true
        )
        let certificate = TransmissionCertificateInfo(
            commonName: "example.com",
            organization: "Example Org",
            validFrom: Date(timeIntervalSince1970: 1_700_000_000),
            validUntil: Date(timeIntervalSince1970: 1_800_000_000),
            sha256Fingerprint: Data([0x01, 0x02, 0x03, 0x04])
        )
        let challenge = TransmissionTrustChallenge(
            identity: identity,
            reason: .untrustedCertificate,
            certificate: certificate
        )
        let prompt = TransmissionTrustPrompt(
            challenge: challenge,
            resolver: { _ in }
        )

        let store = Store(
            initialState: ServerTrustPromptReducer.State(prompt: prompt)
        ) {
            ServerTrustPromptReducer()
        }

        let view = TransmissionTrustPromptView(store: store)
        _ = view.body
    }
}
