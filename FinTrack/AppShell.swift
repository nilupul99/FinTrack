import SwiftUI

struct AppShell: View {
    @Binding var isAuthenticated: Bool
    @Binding var authRoute: AuthRoute
    let userName: String

    var body: some View {
        TabView {
            HomeScreen(userName: userName)
                .tabItem { Label("Home", systemImage: "house.fill") }

            TransactionsScreen()
                .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }

            BudgetScreen()
                .tabItem { Label("Budget", systemImage: "chart.pie.fill") }

            GoalsScreen()
                .tabItem { Label("Goals", systemImage: "target") }

            NavigationStack {
                MoreScreen(
                    userName: userName,
                    isAuthenticated: $isAuthenticated,
                    authRoute: $authRoute
                )
            }
            .tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}
