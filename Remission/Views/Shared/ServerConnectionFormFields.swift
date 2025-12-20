import SwiftUI

struct ServerConnectionFormFields: View {
    @Binding var form: ServerConnectionFormState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            connectionSection
            securitySection
            credentialsSection
        }
    }

    private var connectionSection: some View {
        AppSectionCard(L10n.tr("serverForm.section.connection")) {
            fieldRow(label: L10n.tr("serverForm.placeholder.name")) {
                TextField(
                    "", text: $form.name, prompt: Text(L10n.tr("serverForm.placeholder.name"))
                )
                .accessibilityIdentifier("server_form_name_field")
            }

            Divider()

            fieldRow(label: L10n.tr("serverForm.placeholder.host")) {
                #if os(iOS)
                    TextField(
                        "",
                        text: $form.host,
                        prompt: Text(L10n.tr("serverForm.placeholder.host"))
                    )
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("server_form_host_field")
                #else
                    TextField(
                        "",
                        text: $form.host,
                        prompt: Text(L10n.tr("serverForm.placeholder.host"))
                    )
                    .textContentType(.URL)
                    .accessibilityIdentifier("server_form_host_field")
                #endif
            }

            Divider()

            fieldRow(label: L10n.tr("serverForm.placeholder.port")) {
                #if os(iOS)
                    TextField(
                        "",
                        text: $form.port,
                        prompt: Text(L10n.tr("serverForm.placeholder.port"))
                    )
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("server_form_port_field")
                #else
                    TextField(
                        "",
                        text: $form.port,
                        prompt: Text(L10n.tr("serverForm.placeholder.port"))
                    )
                    .accessibilityIdentifier("server_form_port_field")
                #endif
            }

            Divider()

            fieldRow(label: L10n.tr("serverForm.placeholder.path")) {
                #if os(iOS)
                    TextField(
                        "",
                        text: $form.path,
                        prompt: Text(L10n.tr("serverForm.placeholder.path"))
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("server_form_path_field")
                #else
                    TextField(
                        "",
                        text: $form.path,
                        prompt: Text(L10n.tr("serverForm.placeholder.path"))
                    )
                    .accessibilityIdentifier("server_form_path_field")
                #endif
            }
        }
    }

    private var securitySection: some View {
        AppSectionCard(L10n.tr("serverForm.section.security"), style: .plain) {
            VStack(alignment: .leading, spacing: 12) {
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
                            .font(.subheadline.weight(.semibold))
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
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardSurface(cornerRadius: 14)
        }
    }

    private var credentialsSection: some View {
        AppSectionCard(L10n.tr("serverForm.section.credentials")) {
            fieldRow(label: L10n.tr("serverForm.placeholder.username")) {
                #if os(iOS)
                    TextField(
                        "",
                        text: $form.username,
                        prompt: Text(L10n.tr("serverForm.placeholder.username"))
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("server_form_username_field")
                #else
                    TextField(
                        "",
                        text: $form.username,
                        prompt: Text(L10n.tr("serverForm.placeholder.username"))
                    )
                    .accessibilityIdentifier("server_form_username_field")
                #endif
            }

            Divider()

            fieldRow(label: L10n.tr("serverForm.placeholder.password")) {
                SecureField(
                    "",
                    text: $form.password,
                    prompt: Text(L10n.tr("serverForm.placeholder.password"))
                )
                .accessibilityIdentifier("server_form_password_field")
            }
        }
    }

    private func fieldRow<Content: View>(
        label: String,
        @ViewBuilder field: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            field()
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .frame(maxWidth: 260)
                .appPillSurface()
        }
    }
}
