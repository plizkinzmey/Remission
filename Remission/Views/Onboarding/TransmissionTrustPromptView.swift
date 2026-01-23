import ComposableArchitecture
import SwiftUI

struct TransmissionTrustPromptView: View {
    @Bindable var store: StoreOf<ServerTrustPromptReducer>

    private var challenge: TransmissionTrustChallenge {
        store.prompt.challenge
    }

    private var certificate: TransmissionCertificateInfo {
        challenge.certificate
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Label(
                    L10n.tr("onboarding.trustPrompt.title"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
                .font(.title3.bold())
                Text(L10n.tr("onboarding.trustPrompt.message"))
                    .font(.body)

                certificateDetails

                Spacer()

                VStack(spacing: 12) {
                    Button(role: .destructive) {
                        store.send(.cancelled)
                    } label: {
                        Text(L10n.tr("onboarding.trustPrompt.cancel"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        store.send(.trustConfirmed)
                    } label: {
                        Text(L10n.tr("onboarding.trustPrompt.trust"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle(L10n.tr("onboarding.trustPrompt.navigationTitle"))
        }
    }

    private var certificateDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow(
                title: L10n.tr("onboarding.trustPrompt.server"),
                value: challenge.identity.canonicalIdentifier
            )
            if let cn = certificate.commonName, cn.isEmpty == false {
                detailRow(title: L10n.tr("onboarding.trustPrompt.commonName"), value: cn)
            }
            detailRow(
                title: L10n.tr("onboarding.trustPrompt.fingerprint"), value: fingerprintFormatted)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.monospaced())
        }
    }

    private var fingerprintFormatted: String {
        certificate.fingerprintHexString
            .uppercased()
            .chunked(into: 4)
            .joined(separator: " ")
    }
}

extension String {
    fileprivate func chunked(into size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map { index in
            let start = self.index(startIndex, offsetBy: index)
            let end = self.index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            return String(self[start..<end])
        }
    }
}
