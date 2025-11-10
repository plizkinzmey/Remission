import SwiftUI

struct ServerConnectionFormFields: View {
    @Binding var form: ServerConnectionFormState

    var body: some View {
        connectionSection
        securitySection
        credentialsSection
    }

    private var connectionSection: some View {
        Section("Подключение") {
            TextField("Имя сервера", text: $form.name)
            #if os(iOS)
                TextField("Host", text: $form.host)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            #else
                TextField("Host", text: $form.host)
                    .textContentType(.URL)
            #endif
            #if os(iOS)
                TextField("Порт", text: $form.port)
                    .keyboardType(.numberPad)
            #else
                TextField("Порт", text: $form.port)
            #endif
            #if os(iOS)
                TextField("Путь", text: $form.path)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            #else
                TextField("Путь", text: $form.path)
            #endif
        }
    }

    private var securitySection: some View {
        Section("Безопасность") {
            Picker("Протокол", selection: $form.transport) {
                ForEach(ServerConnectionFormState.Transport.allCases, id: \.self) { transport in
                    Text(transport.title).tag(transport)
                }
            }
            .pickerStyle(.segmented)

            if form.transport == .https {
                Toggle(
                    "Разрешить недоверенные сертификаты",
                    isOn: $form.allowUntrustedCertificates
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HTTP небезопасен")
                        .font(.subheadline)
                        .bold()
                    Text("Данные (включая логин и пароль) передаются без шифрования.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle(
                        "Не предупреждать для этого сервера",
                        isOn: $form.suppressInsecureWarning
                    )
                    .toggleStyle(.switch)
                }
            }
        }
    }

    private var credentialsSection: some View {
        Section("Учетные данные") {
            #if os(iOS)
                TextField("Имя пользователя", text: $form.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            #else
                TextField("Имя пользователя", text: $form.username)
            #endif
            SecureField("Пароль", text: $form.password)
        }
    }
}
