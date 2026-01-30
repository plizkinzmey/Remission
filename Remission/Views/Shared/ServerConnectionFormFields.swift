import SwiftUI

struct ServerConnectionFormFields: View {
    @Binding var form: ServerConnectionFormState
    @State private var isPasswordVisible: Bool = false
    @State private var labelWidth: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            connectionSection
            credentialsSection
        }
        .onPreferenceChange(LabelWidthPreferenceKey.self) { widths in
            if let max = widths.max(), max != labelWidth {
                labelWidth = max
            }
        }
    }

    private var connectionSection: some View {
        AppSectionCard(L10n.tr("serverForm.section.connection")) {
            VStack(alignment: .leading, spacing: 10) {
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

                VStack(spacing: 10) {
                    AppFormField(L10n.tr("serverForm.placeholder.name"), labelWidth: labelWidth) {
                        TextField(
                            L10n.tr("serverForm.placeholder.name"),
                            text: $form.name
                        )
                        .textFieldStyle(.appFormField)
                        .accessibilityIdentifier("server_form_name_field")
                    }

                    Divider()

                    AppFormField(L10n.tr("serverForm.placeholder.host"), labelWidth: labelWidth) {
                        TextField(
                            L10n.tr("serverForm.placeholder.host"),
                            text: $form.host
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
                            text: $form.port
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
                            text: $form.path
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
            VStack(spacing: 10) {
                AppFormField(L10n.tr("serverForm.placeholder.username"), labelWidth: labelWidth) {
                    TextField(
                        L10n.tr("serverForm.placeholder.username"),
                        text: $form.username
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
                                    text: $form.password
                                )
                            } else {
                                SecureField(
                                    L10n.tr("serverForm.placeholder.password"),
                                    text: $form.password
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
