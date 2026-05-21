import SwiftUI

struct ServerConnectionFormFields: View {
    @Binding var form: ServerConnectionFormState
    @State private var isPasswordVisible: Bool = false

    var body: some View {
        #if os(macOS)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                // Раздел 1: Подключение
                Text(L10n.tr("serverForm.section.connection"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .gridCellColumns(2)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                    .lineLimit(1)

                GridRow {
                    Text(L10n.tr("serverForm.transport.label"))
                        .gridColumnAlignment(.trailing)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Picker("", selection: $form.transport) {
                        ForEach(ServerConnectionFormState.Transport.allCases, id: \.self) {
                            transport in
                            Text(transport.title).tag(transport)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .tint(nil)
                    .accessibilityIdentifier("server_form_transport_picker")
                }

                GridRow {
                    Text(L10n.tr("serverForm.placeholder.name"))
                        .gridColumnAlignment(.trailing)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    SanitizedTextField(
                        L10n.tr("serverForm.placeholder.name"),
                        text: $form.name
                    )
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                    .accessibilityIdentifier("server_form_name_field")
                }

                GridRow {
                    Text(L10n.tr("serverForm.placeholder.host"))
                        .gridColumnAlignment(.trailing)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    SanitizedTextField(
                        L10n.tr("serverForm.placeholder.host"),
                        text: $form.host
                    )
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                    .accessibilityIdentifier("server_form_host_field")
                }

                GridRow {
                    Text(L10n.tr("serverForm.placeholder.port"))
                        .gridColumnAlignment(.trailing)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    SanitizedTextField(
                        L10n.tr("serverForm.placeholder.port"),
                        text: $form.port
                    )
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                    .accessibilityIdentifier("server_form_port_field")
                }

                GridRow {
                    Text(L10n.tr("serverForm.placeholder.path"))
                        .gridColumnAlignment(.trailing)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    SanitizedTextField(
                        L10n.tr("serverForm.placeholder.path"),
                        text: $form.path
                    )
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                    .accessibilityIdentifier("server_form_path_field")
                }

                // Раздел 2: Аутентификация
                Text(L10n.tr("serverForm.section.credentials"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .gridCellColumns(2)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
                    .lineLimit(1)

                GridRow {
                    Text(L10n.tr("serverForm.placeholder.username"))
                        .gridColumnAlignment(.trailing)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    SanitizedTextField(
                        L10n.tr("serverForm.placeholder.username"),
                        text: $form.username
                    )
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                    .accessibilityIdentifier("server_form_username_field")
                }

                GridRow {
                    Text(L10n.tr("serverForm.placeholder.password"))
                        .gridColumnAlignment(.trailing)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    HStack(spacing: 6) {
                        SanitizedTextField(
                            L10n.tr("serverForm.placeholder.password"),
                            text: $form.password,
                            isSecure: !isPasswordVisible
                        )
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        #else
            Group {
                Section(header: Text(L10n.tr("serverForm.section.connection")).lineLimit(1)) {
                    Picker(L10n.tr("serverForm.transport.label"), selection: $form.transport) {
                        ForEach(ServerConnectionFormState.Transport.allCases, id: \.self) {
                            transport in
                            Text(transport.title).tag(transport)
                        }
                    }
                    .accessibilityIdentifier("server_form_transport_picker")
                    .pickerStyle(.segmented)

                    LabeledContent(L10n.tr("serverForm.placeholder.name")) {
                        SanitizedTextField(
                            L10n.tr("serverForm.placeholder.name"),
                            text: $form.name
                        )
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
                        .accessibilityIdentifier("server_form_name_field")
                    }

                    LabeledContent(L10n.tr("serverForm.placeholder.host")) {
                        SanitizedTextField(
                            L10n.tr("serverForm.placeholder.host"),
                            text: $form.host
                        )
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("server_form_host_field")
                    }

                    LabeledContent(L10n.tr("serverForm.placeholder.port")) {
                        SanitizedTextField(
                            L10n.tr("serverForm.placeholder.port"),
                            text: $form.port
                        )
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("server_form_port_field")
                    }

                    LabeledContent(L10n.tr("serverForm.placeholder.path")) {
                        SanitizedTextField(
                            L10n.tr("serverForm.placeholder.path"),
                            text: $form.path
                        )
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("server_form_path_field")
                    }
                }

                Section(header: Text(L10n.tr("serverForm.section.credentials")).lineLimit(1)) {
                    LabeledContent(L10n.tr("serverForm.placeholder.username")) {
                        SanitizedTextField(
                            L10n.tr("serverForm.placeholder.username"),
                            text: $form.username
                        )
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("server_form_username_field")
                    }

                    LabeledContent(L10n.tr("serverForm.placeholder.password")) {
                        HStack(spacing: 6) {
                            SanitizedTextField(
                                L10n.tr("serverForm.placeholder.password"),
                                text: $form.password,
                                isSecure: !isPasswordVisible
                            )
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1)
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
        #endif
    }
}
