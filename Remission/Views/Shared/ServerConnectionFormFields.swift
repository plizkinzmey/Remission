import SwiftUI

struct ServerConnectionFormFields: View {
    @Binding var form: ServerConnectionFormState
    @State private var isPasswordVisible: Bool = false
    @State private var labelWidth: CGFloat = 80  // Фиксированная ширина для выравнивания

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            connectionSection
            credentialsSection
        }
    }

    private var connectionSection: some View {
        AppSectionCard(L10n.tr("serverForm.section.connection")) {
            VStack(alignment: .leading, spacing: 12) {
                Picker(L10n.tr("serverForm.transport.label"), selection: $form.transport) {
                    ForEach(ServerConnectionFormState.Transport.allCases, id: \.self) { transport in
                        Text(transport.title).tag(transport)
                    }
                }
                .accessibilityIdentifier("server_form_transport_picker")
                .pickerStyle(.segmented)
                #if os(macOS)
                    .controlSize(.large)
                    .tint(.blue)
                #endif

                Divider()

                VStack(spacing: 12) {
                    AppFormField(L10n.tr("serverForm.placeholder.name"), labelWidth: labelWidth) {
                        TextField(
                            L10n.tr("serverForm.placeholder.name"),
                            text: $form.name.filtered(allowed: .alphanumerics)
                        )
                        .textFieldStyle(.appFormField)
                        .accessibilityIdentifier("server_form_name_field")
                    }

                    Divider()

                    AppFormField(L10n.tr("serverForm.placeholder.host"), labelWidth: labelWidth) {
                        TextField(
                            L10n.tr("serverForm.placeholder.host"),
                            text: $form.host.filteredASCII(allowed: .hostCharacters)
                        )
                        .textFieldStyle(.appFormField)
                        .textContentType(.URL)
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        #endif
                        .accessibilityIdentifier("server_form_host_field")
                    }

                    Divider()

                    AppFormField(L10n.tr("serverForm.placeholder.port"), labelWidth: labelWidth) {
                        TextField(
                            L10n.tr("serverForm.placeholder.port"),
                            text: $form.port.filtered(allowed: .decimalDigits)
                        )
                        .textFieldStyle(.appFormField)
                        #if os(iOS)
                            .keyboardType(.numberPad)
                        #endif
                        .accessibilityIdentifier("server_form_port_field")
                    }

                    Divider()

                    AppFormField(L10n.tr("serverForm.placeholder.path"), labelWidth: labelWidth) {
                        TextField(
                            L10n.tr("serverForm.placeholder.path"),
                            text: $form.path.filteredASCII(allowed: .pathCharacters)
                        )
                        .textFieldStyle(.appFormField)
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        #endif
                        .accessibilityIdentifier("server_form_path_field")
                    }
                }
            }
        }
    }

    private var credentialsSection: some View {
        AppSectionCard(L10n.tr("serverForm.section.credentials")) {
            VStack(spacing: 12) {
                AppFormField(L10n.tr("serverForm.placeholder.username"), labelWidth: labelWidth) {
                    TextField(
                        L10n.tr("serverForm.placeholder.username"),
                        text: $form.username.filtered(allowed: .alphanumerics)
                    )
                    .textFieldStyle(.appFormField)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #endif
                    .accessibilityIdentifier("server_form_username_field")
                }

                Divider()

                AppFormField(L10n.tr("serverForm.placeholder.password"), labelWidth: labelWidth) {
                    HStack(spacing: 6) {
                        Group {
                            if isPasswordVisible {
                                TextField(
                                    L10n.tr("serverForm.placeholder.password"),
                                    text: $form.password.filteredASCII(allowed: .alphanumerics)
                                )
                            } else {
                                SecureField(
                                    L10n.tr("serverForm.placeholder.password"),
                                    text: $form.password.filteredASCII(allowed: .alphanumerics)
                                )
                            }
                        }
                        .textFieldStyle(.appFormField)
                        .accessibilityIdentifier("server_form_password_field")

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("server_form_password_toggle")
                        .accessibilityLabel(
                            isPasswordVisible
                                ? L10n.tr("serverForm.password.hide")
                                : L10n.tr("serverForm.password.show")
                        )
                    }
                }
            }
        }
    }
}
