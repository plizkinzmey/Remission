import SwiftUI

struct ServerConnectionFormFields: View {
    @Binding var form: ServerConnectionFormState
    @State private var isPasswordVisible: Bool = false

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

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    fieldRow(label: L10n.tr("serverForm.placeholder.name")) {
                        TextField(
                            "",
                            text: filteredBinding(
                                $form.name,
                                allowed: .alphanumerics
                            ),
                            prompt: Text(L10n.tr("serverForm.placeholder.name"))
                        )
                        .accessibilityIdentifier("server_form_name_field")
                    }

                    Divider()
                        .gridCellColumns(2)

                    fieldRow(label: L10n.tr("serverForm.placeholder.host")) {
                        #if os(iOS)
                            TextField(
                                "",
                                text: filteredBinding(
                                    $form.host,
                                    allowed: .hostCharacters
                                ),
                                prompt: Text(L10n.tr("serverForm.placeholder.host"))
                            )
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("server_form_host_field")
                        #else
                            TextField(
                                "",
                                text: filteredBinding(
                                    $form.host,
                                    allowed: .hostCharacters
                                ),
                                prompt: Text(L10n.tr("serverForm.placeholder.host"))
                            )
                            .textContentType(.URL)
                            .accessibilityIdentifier("server_form_host_field")
                        #endif
                    }

                    Divider()
                        .gridCellColumns(2)

                    fieldRow(label: L10n.tr("serverForm.placeholder.port")) {
                        #if os(iOS)
                            TextField(
                                "",
                                text: filteredBinding(
                                    $form.port,
                                    allowed: .decimalDigits
                                ),
                                prompt: Text(L10n.tr("serverForm.placeholder.port"))
                            )
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("server_form_port_field")
                        #else
                            TextField(
                                "",
                                text: filteredBinding(
                                    $form.port,
                                    allowed: .decimalDigits
                                ),
                                prompt: Text(L10n.tr("serverForm.placeholder.port"))
                            )
                            .accessibilityIdentifier("server_form_port_field")
                        #endif
                    }

                    Divider()
                        .gridCellColumns(2)

                    fieldRow(label: L10n.tr("serverForm.placeholder.path")) {
                        #if os(iOS)
                            TextField(
                                "",
                                text: filteredBinding(
                                    $form.path,
                                    allowed: .pathCharacters
                                ),
                                prompt: Text(L10n.tr("serverForm.placeholder.path"))
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("server_form_path_field")
                        #else
                            TextField(
                                "",
                                text: filteredBinding(
                                    $form.path,
                                    allowed: .pathCharacters
                                ),
                                prompt: Text(L10n.tr("serverForm.placeholder.path"))
                            )
                            .accessibilityIdentifier("server_form_path_field")
                        #endif
                    }
                }
            }
        }
    }

    private var credentialsSection: some View {
        AppSectionCard(L10n.tr("serverForm.section.credentials")) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                fieldRow(label: L10n.tr("serverForm.placeholder.username")) {
                    #if os(iOS)
                        TextField(
                            "",
                            text: filteredBinding(
                                $form.username,
                                allowed: .alphanumerics
                            ),
                            prompt: Text(L10n.tr("serverForm.placeholder.username"))
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("server_form_username_field")
                    #else
                        TextField(
                            "",
                            text: filteredBinding(
                                $form.username,
                                allowed: .alphanumerics
                            ),
                            prompt: Text(L10n.tr("serverForm.placeholder.username"))
                        )
                        .accessibilityIdentifier("server_form_username_field")
                    #endif
                }

                Divider()
                    .gridCellColumns(2)

                fieldRow(label: L10n.tr("serverForm.placeholder.password")) {
                    HStack(spacing: 6) {
                        Group {
                            if isPasswordVisible {
                                TextField(
                                    "",
                                    text: filteredBinding(
                                        $form.password,
                                        allowed: .alphanumerics
                                    ),
                                    prompt: Text(L10n.tr("serverForm.placeholder.password"))
                                )
                            } else {
                                SecureField(
                                    "",
                                    text: filteredBinding(
                                        $form.password,
                                        allowed: .alphanumerics
                                    ),
                                    prompt: Text(L10n.tr("serverForm.placeholder.password"))
                                )
                            }
                        }
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

    private func fieldRow<Content: View>(
        label: String,
        @ViewBuilder field: () -> Content
    ) -> some View {
        GridRow {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            field()
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .frame(maxWidth: 260)
                .appPillSurface()
        }
    }

    private func filteredBinding(
        _ text: Binding<String>,
        allowed: CharacterSet
    ) -> Binding<String> {
        Binding(
            get: { text.wrappedValue },
            set: { newValue in
                text.wrappedValue = filterASCII(newValue, allowed: allowed)
            }
        )
    }

    private func filterASCII(
        _ value: String,
        allowed: CharacterSet
    ) -> String {
        String(
            value.unicodeScalars
                .filter { $0.isASCII && allowed.contains($0) }
                .map(Character.init)
        )
    }
}

extension CharacterSet {
    fileprivate static let hostCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: ".-")
        return set
    }()

    fileprivate static let pathCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "/-_")
        return set
    }()
}
