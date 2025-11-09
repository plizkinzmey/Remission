import ComposableArchitecture
import SwiftUI

struct TransmissionTrustPromptView: View {
    @Bindable var store: StoreOf<OnboardingReducer.TrustPromptReducer>

    private var challenge: TransmissionTrustChallenge {
        store.prompt.challenge
    }

    private var certificate: TransmissionCertificateInfo {
        challenge.certificate
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Label("Ненадёжный сертификат", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3.bold())
                Text("Не удалось подтвердить сертификат сервера. Доверять этому сертификату?")
                    .font(.body)

                certificateDetails

                Spacer()

                VStack(spacing: 12) {
                    Button(role: .destructive) {
                        store.send(.cancelled)
                    } label: {
                        Text("Отмена")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        store.send(.trustConfirmed)
                    } label: {
                        Text("Доверять")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Доверие сертификату")
        }
    }

    private var certificateDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow(title: "Сервер", value: challenge.identity.canonicalIdentifier)
            if let cn = certificate.commonName, cn.isEmpty == false {
                detailRow(title: "CN", value: cn)
            }
            detailRow(title: "Отпечаток SHA‑256", value: fingerprintFormatted)
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
