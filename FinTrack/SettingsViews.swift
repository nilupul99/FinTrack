import SwiftUI

struct SettingsScreen: View {
    @AppStorage("currencyCode") private var currencyCode = "LKR"
    @AppStorage("insightsAPIURL") private var insightsAPIURL = ""
    @AppStorage("faceIDEnabled") private var faceIDEnabled = true
    @AppStorage("receiptScanningEnabled") private var receiptScanningEnabled = true

    private let currencies = ["LKR", "USD", "GBP", "EUR", "AUD", "CAD", "INR", "JPY"]

    var body: some View {
        Form {
            SecuritySettingsSection(
                faceIDEnabled: $faceIDEnabled,
                receiptScanningEnabled: $receiptScanningEnabled
            )
            CurrencySettingsSection(
                currencyCode: $currencyCode,
                currencies: currencies
            )
            APIInsightsSettingsSection(insightsAPIURL: $insightsAPIURL)
        }
        .navigationTitle("Settings")
        .navigationBarBackButtonHidden(true)
    }
}

struct SecuritySettingsSection: View {
    @Binding var faceIDEnabled: Bool
    @Binding var receiptScanningEnabled: Bool

    var body: some View {
        Section("Security") {
            Toggle("Face ID", isOn: $faceIDEnabled)
            Toggle("Receipt scanning", isOn: $receiptScanningEnabled)
        }
    }
}

struct CurrencySettingsSection: View {
    @Binding var currencyCode: String
    let currencies: [String]

    var body: some View {
        Section("Currency") {
            Picker("App Currency", selection: $currencyCode) {
                ForEach(currencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }

            HStack {
                Text("Preview")
                Spacer()
                CurrencyText(amount: 12460.75)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct APIInsightsSettingsSection: View {
    @Binding var insightsAPIURL: String

    var body: some View {
        Section("API Insights") {
            TextField("https://api.example.com/insights", text: $insightsAPIURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            Text("Leave this blank to hide API insights.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
