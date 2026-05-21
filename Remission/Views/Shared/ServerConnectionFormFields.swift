import SwiftUI

struct ServerConnectionFormFields: View {
    @Binding var form: ServerConnectionFormState
    @State private var isPasswordVisible: Bool = false

    var body: some View {
        Group {
            Section(header: Text(L10n.tr("serverForm.section.connection"))) {
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

                LabeledContent(L10n.tr("serverForm.placeholder.name")) {
                    TextField(
                        L10n.tr("serverForm.placeholder.name"),
                        text: $form.name
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("server_form_name_field")
                }

                LabeledContent(L10n.tr("serverForm.placeholder.host")) {
                    TextField(
                        L10n.tr("serverForm.placeholder.host"),
                        text: $form.host
                    )
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #endif
                    .accessibilityIdentifier("server_form_host_field")
                }

                LabeledContent(L10n.tr("serverForm.placeholder.port")) {
                    TextField(
                        L10n.tr("serverForm.placeholder.port"),
                        text: $form.port
                    )
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                    .accessibilityIdentifier("server_form_port_field")
                }

                LabeledContent(L10n.tr("serverForm.placeholder.path")) {
                    TextField(
                        L10n.tr("serverForm.placeholder.path"),
                        text: $form.path
                    )
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #endif
                    .accessibilityIdentifier("server_form_path_field")
                }
            }

            Section(header: Text(L10n.tr("serverForm.section.credentials"))) {
                LabeledContent(L10n.tr("serverForm.placeholder.username")) {
                    TextField(
                        L10n.tr("serverForm.placeholder.username"),
                        text: $form.username
                    )
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #endif
                    .accessibilityIdentifier("server_form_username_field")
                }

                LabeledContent(L10n.tr("serverForm.placeholder.password")) {
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
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("server_form_password_field")

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.bordered)
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
