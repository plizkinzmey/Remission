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
                .accessibilityIdentifier("server_form_name_field")
            #if os(iOS)
                TextField(L10n.tr("serverForm.placeholder.host"), text: $form.host)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("server_form_host_field")
            #else
                TextField(L10n.tr("serverForm.placeholder.host"), text: $form.host)
                    .textContentType(.URL)
                    .accessibilityIdentifier("server_form_host_field")
            #endif
            #if os(iOS)
                TextField(L10n.tr("serverForm.placeholder.port"), text: $form.port)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("server_form_port_field")
            #else
                TextField(L10n.tr("serverForm.placeholder.port"), text: $form.port)
                    .accessibilityIdentifier("server_form_port_field")
            #endif
            #if os(iOS)
                TextField(L10n.tr("serverForm.placeholder.path"), text: $form.path)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("server_form_path_field")
            #else
                TextField(L10n.tr("serverForm.placeholder.path"), text: $form.path)
                    .accessibilityIdentifier("server_form_path_field")
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
            .accessibilityIdentifier("server_form_transport_picker")
            .pickerStyle(.segmented)

            if form.transport == .https {
                Toggle(
                    L10n.tr("serverForm.security.allowUntrusted"),
                    isOn: $form.allowUntrustedCertificates
                )
                .accessibilityIdentifier("server_form_allow_untrusted_toggle")
                .accessibilityHint(L10n.tr("serverForm.security.allowUntrusted"))
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
                    .accessibilityIdentifier("server_form_suppress_warning_toggle")
                    .accessibilityHint(L10n.tr("serverForm.security.httpWarning.suppress"))
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
                    .accessibilityIdentifier("server_form_username_field")
            #else
                TextField(L10n.tr("serverForm.placeholder.username"), text: $form.username)
                    .accessibilityIdentifier("server_form_username_field")
            #endif
            SecureField(L10n.tr("serverForm.placeholder.password"), text: $form.password)
                .accessibilityIdentifier("server_form_password_field")
        }
    }
}
