import SwiftUI

struct ServerConnectionFormFields: View {
    @Binding var form: ServerConnectionFormState

    var body: some View {
        connectionSection
        securitySection
        credentialsSection
    }

    private var connectionSection: some View {
        Section(L10n.tr("serverForm.section.connection")) {
            TextField(L10n.tr("serverForm.placeholder.name"), text: $form.name)
            #if os(iOS)
                TextField(L10n.tr("serverForm.placeholder.host"), text: $form.host)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            #else
                TextField(L10n.tr("serverForm.placeholder.host"), text: $form.host)
                    .textContentType(.URL)
            #endif
            #if os(iOS)
                TextField(L10n.tr("serverForm.placeholder.port"), text: $form.port)
                    .keyboardType(.numberPad)
            #else
                TextField(L10n.tr("serverForm.placeholder.port"), text: $form.port)
            #endif
            #if os(iOS)
                TextField(L10n.tr("serverForm.placeholder.path"), text: $form.path)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            #else
                TextField(L10n.tr("serverForm.placeholder.path"), text: $form.path)
            #endif
        }
    }

    private var securitySection: some View {
        Section(L10n.tr("serverForm.section.security")) {
            Picker(L10n.tr("serverForm.transport.label"), selection: $form.transport) {
                ForEach(ServerConnectionFormState.Transport.allCases, id: \.self) { transport in
                    Text(transport.title).tag(transport)
                }
            }
            .pickerStyle(.segmented)

            if form.transport == .https {
                Toggle(
                    L10n.tr("serverForm.security.allowUntrusted"),
                    isOn: $form.allowUntrustedCertificates
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("serverForm.security.httpWarning.title"))
                        .font(.subheadline)
                        .bold()
                    Text(L10n.tr("serverForm.security.httpWarning.message"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle(
                        L10n.tr("serverForm.security.httpWarning.suppress"),
                        isOn: $form.suppressInsecureWarning
                    )
                    .toggleStyle(.switch)
                }
            }
        }
    }

    private var credentialsSection: some View {
        Section(L10n.tr("serverForm.section.credentials")) {
            #if os(iOS)
                TextField(L10n.tr("serverForm.placeholder.username"), text: $form.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            #else
                TextField(L10n.tr("serverForm.placeholder.username"), text: $form.username)
            #endif
            SecureField(L10n.tr("serverForm.placeholder.password"), text: $form.password)
        }
    }
}
