# FinTrack

FinTrack is an iOS personal-finance tracker built with SwiftUI. It lets a user record income and expenses, manage budgets and goals, schedule recurring transactions, scan receipts, view on-device insights, and synchronise financial data between devices.

## Main Features

- Email/password account registration and login with Supabase Auth
- Optional Face ID unlock for an existing signed-in session
- Core Data local persistence for transactions, budgets, and goals
- Supabase cloud synchronisation and realtime refresh
- Income, expenses, custom categories, and editable transactions
- Category budgets and goal progress
- Recurring income and expense schedules
- Local notifications for sign-in activity, budgets, goals, and recurring reminders
- Receipt scanning with VisionKit and Vision, including a review step before saving
- Core ML overspending-risk and spending-forecast insights
- Category spending and savings donut chart
- Financial news loaded from a public REST API

## Requirements

- macOS with the Xcode version used for this project or newer
- iOS Simulator, or a connected iPhone configured for development
- Internet connection for authentication, cloud sync, and financial news

The project currently targets the iOS SDK configured in Xcode. Use the `FinTrack` scheme and select an iPhone simulator if you do not have a physical device available.

## Run the App

1. Clone or download the repository.
2. Open `FinTrack.xcodeproj` in Xcode.
3. Select the **FinTrack** scheme.
4. Select an iPhone Simulator, for example **iPhone 16**, or a connected iPhone.
5. Press **Run** (`Command + R`).
6. On the Welcome screen, create an account or log in with an existing account.

If running on a physical device, select your Personal Team under **Signing & Capabilities** for the app and test targets. The project does not require a paid Apple Developer Program membership for local simulator development.

## Quick Feature Walkthrough

1. Create an account and sign in.
2. On **Home**, use the quick actions to add income or an expense.
3. Open **Activity** to edit, delete, scan, or review transactions.
4. Open **Budget** to create a budget for a category. Matching expenses update the budget progress.
5. Open **Goals** to create a category goal. Transactions in the same category update its completion percentage.
6. Open **More** for Insights, Financial News, Profile, and Settings.
7. In **Settings**, enable or disable Face ID, receipt scanning, notification types, and choose a currency.

## Run Tests

The unit tests use the Swift Testing framework. The project also includes UI tests.

1. In Xcode, select **Product > Test** or press `Command + U`.
2. The `FinTrackTests` target checks financial rules for goals, budgets, and recurring transaction signs.
3. The `FinTrackUITests` target checks basic launch behaviour.

## Backend: Supabase

FinTrack uses Supabase for authentication and cloud storage. The currently configured project endpoint is:

`https://lgspwlcdhugqvuchgmyx.supabase.co`

### Accessing the Dashboard

1. Sign in to [Supabase Dashboard](https://supabase.com/dashboard) using the owner account for the project.
2. Select the project with reference `lgspwlcdhugqvuchgmyx`.
3. Use **Authentication > Users** to review registered application users.
4. Use **Table Editor > financial_records** to inspect synchronised financial records.
5. Use **Logs** to troubleshoot authentication, REST, or Realtime errors.

Dashboard access is only available to people invited to the Supabase project. For assessment, invite the marker as a project member only if your lecturer specifically requests dashboard access. Otherwise, create a separate marker test account in the app and demonstrate the synchronised records from the app itself.

### Backend Tables and Data

The main table is `financial_records`. It stores a user-scoped cloud representation of local finance data.

| Column | Purpose |
|---|---|
| `id` | Stable cloud identifier for the record. |
| `user_id` | Supabase authenticated user ID. |
| `record_type` | `transaction`, `budget`, or `goal`. Recurring schedules are stored in a compatible transaction format. |
| `payload` | JSON data such as title, category, amount, limit, target, cadence, and type information. |
| `is_deleted` | Supports synchronisation/deletion handling where configured. |

The app sends ordinary expenses as negative amounts and income as positive amounts. Recurring schedules retain an explicit `isExpense` value as well as their signed amount.

### Authentication and Security

The app authenticates users through Supabase email/password authentication. A saved session is stored locally using secure storage and is used to authorise sync requests.

The app uses the Supabase anonymous/public key only for client requests. Never commit or share any of the following:

- Supabase service-role key
- Database password
- Personal Supabase account password
- Marker test-account password in a public repository

Row Level Security should remain enabled on `financial_records`. Policies must allow a user to read and modify only records where `user_id` matches `auth.uid()`.

### Using a Different Supabase Project

To use a separate Supabase backend:

1. Create a Supabase project and enable Email authentication.
2. Create the `financial_records` table with the fields described above.
3. Add an appropriate unique constraint for `(user_id, id)` because the app uses upsert behaviour.
4. Enable Row Level Security and add authenticated-user policies.
5. Enable Realtime replication for `financial_records` if cross-device live updates are required.
6. Update `baseURL` and the anonymous key in `FinTrack/SupabaseAuthService.swift` with your own project values.

Do not place service-role credentials in the iOS app. In a production project, move public configuration into an untracked configuration file or build setting rather than hard-coding it in source.

## External Financial News API

The Financial News screen fetches article data from Capital Data Wire:

`https://capitaldatawire.com/api/v1/articles?limit=20`

The request is made with `URLSession` in `FinTrack/NewsViews.swift`. The app decodes the JSON response into `FinancialNewsArticle` values and shows a loading or error state when needed.

## Advanced iOS Features

### Receipt scanning

VisionKit presents the scanner and Vision performs on-device text recognition. The user reviews the recognised receipt amount before saving it as a transaction.

### Core ML insights

The app includes `OverspendingRisk.mlmodel` and `SpendingForecast.mlmodel`. Insights are generated on-device from local financial totals, categories, and transaction activity. The included models use synthetic demonstration data and should not be interpreted as professional financial advice.

## Project Structure

```text
FinTrack/
├── AppShell.swift                  Main tab navigation
├── ContentView.swift               Authentication/app entry flow
├── HomeViews.swift                 Dashboard
├── TransactionsViews.swift         Transactions, recurring items, receipt scanning
├── BudgetViews.swift               Budgets
├── GoalsViews.swift                Goals
├── AnalyticsViews.swift            Charts and Core ML insights
├── NewsViews.swift                 Financial news API
├── SupabaseAuthService.swift       Supabase authentication
├── FinancialCloudSyncService.swift Cloud and realtime synchronisation
├── FinTrackServices.swift          Notifications and insight services
├── Persistence.swift               Core Data setup
└── FinTrackTests/                  Swift Testing unit tests
```

## Known Limitations

- Push notifications to a fully closed app require APNs credentials and a paid Apple Developer Program configuration; the project currently uses local notifications.
- Cloud sync requires an internet connection and a valid Supabase session.
- The Core ML models are demonstration models trained from synthetic data.
- Receipt OCR can make mistakes, so the review-and-edit screen is intentionally required.
