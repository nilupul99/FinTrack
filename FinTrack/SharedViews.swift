import SwiftUI

struct CurrencyText: View {
    let amount: Double
    @AppStorage("currencyCode") private var currencyCode = "USD"

    var body: some View {
        Text(amount, format: .currency(code: currencyCode))
    }
}

struct AuthHeader: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 74, height: 74)
                .background(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .blue.opacity(0.25), radius: 18, x: 0, y: 10)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 28)
    }
}

struct AuthTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let systemImage: String

    var body: some View {
        Label {
            TextField(title, text: $text)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
                .frame(width: 24)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AuthSecureField: View {
    let title: LocalizedStringKey
    @Binding var text: String

    var body: some View {
        Label {
            SecureField(title, text: $text)
        } icon: {
            Image(systemName: "lock")
                .foregroundStyle(.blue)
                .frame(width: 24)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AuthBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(.systemGroupedBackground), Color.blue.opacity(0.10), Color(.systemGroupedBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    let actionTitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Button(actionTitle, action: action)
                .font(.subheadline.weight(.semibold))
        }
    }
}

struct TransactionRow: View {
    let transaction: TransactionRowData

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: transaction.symbolName)
                .font(.headline)
                .foregroundStyle(transaction.tint)
                .frame(width: 44, height: 44)
                .background(transaction.tint.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant)
                    .font(.subheadline.weight(.semibold))
                Text(transaction.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            CurrencyText(amount: transaction.amount)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(transaction.amount >= 0 ? .green : .primary)
        }
        .padding(.vertical, 14)
    }
}

struct RecurringRow: View {
    let title: String
    let cadence: String
    let amount: Double
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(cadence)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            CurrencyText(amount: amount)
                .font(.headline)
                .foregroundStyle(amount >= 0 ? .green : .primary)
        }
        .padding(.vertical, 6)
    }
}
