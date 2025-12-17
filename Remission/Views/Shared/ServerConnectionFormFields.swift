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
            LabeledContent {
                TextField(
                    "", text: $form.name, prompt: Text(L10n.tr("serverForm.placeholder.name"))
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("server_form_name_field")
            } label: {
                Text(L10n.tr("serverForm.placeholder.name"))
            }

            LabeledContent {
                #if os(iOS)
                    TextField(
                        "",
                        text: $form.host,
                        prompt: Text(L10n.tr("serverForm.placeholder.host"))
                    )
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("server_form_host_field")
                #else
                    TextField(
                        "",
                        text: $form.host,
                        prompt: Text(L10n.tr("serverForm.placeholder.host"))
                    )
                    .textContentType(.URL)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("server_form_host_field")
                #endif
            } label: {
                Text(L10n.tr("serverForm.placeholder.host"))
            }

            LabeledContent {
                #if os(iOS)
                    TextField(
                        "",
                        text: $form.port,
                        prompt: Text(L10n.tr("serverForm.placeholder.port"))
                    )
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("server_form_port_field")
                #else
                    TextField(
                        "",
                        text: $form.port,
                        prompt: Text(L10n.tr("serverForm.placeholder.port"))
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("server_form_port_field")
                #endif
            } label: {
                Text(L10n.tr("serverForm.placeholder.port"))
            }

            LabeledContent {
                #if os(iOS)
                    TextField(
                        "",
                        text: $form.path,
                        prompt: Text(L10n.tr("serverForm.placeholder.path"))
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("server_form_path_field")
                #else
                    TextField(
                        "",
                        text: $form.path,
                        prompt: Text(L10n.tr("serverForm.placeholder.path"))
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("server_form_path_field")
                #endif
            } label: {
                Text(L10n.tr("serverForm.placeholder.path"))
            }
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
            LabeledContent {
                #if os(iOS)
                    TextField(
                        "",
                        text: $form.username,
                        prompt: Text(L10n.tr("serverForm.placeholder.username"))
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("server_form_username_field")
                #else
                    TextField(
                        "",
                        text: $form.username,
                        prompt: Text(L10n.tr("serverForm.placeholder.username"))
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("server_form_username_field")
                #endif
            } label: {
                Text(L10n.tr("serverForm.placeholder.username"))
            }

            LabeledContent {
                SecureField(
                    "",
                    text: $form.password,
                    prompt: Text(L10n.tr("serverForm.placeholder.password"))
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("server_form_password_field")
            } label: {
                Text(L10n.tr("serverForm.placeholder.password"))
            }
        }
    }
}
