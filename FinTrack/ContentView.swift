//
//  ContentView.swift
//  FinTrack
//
//  Created by Nilupul Rambukwelle on 2026-10-10.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var authRoute: AuthRoute = .welcome
    @State private var isAuthenticated = false
    @State private var currentUserName = ""
    @AppStorage("activeUserEmail") private var activeUserEmail = ""

    var body: some View {
        Group {
            if isAuthenticated {
                AppShell(
                    isAuthenticated: $isAuthenticated,
                    authRoute: $authRoute,
                    userName: currentUserName
                )
            } else {
                AuthFlowView(
                    authRoute: $authRoute,
                    isAuthenticated: $isAuthenticated,
                    currentUserName: $currentUserName,
                    viewContext: viewContext
                )
            }
        }
        .tint(.blue)
        .task {
            await NotificationManager.shared.requestAuthorization()

            if let user = await SupabaseAuthService.shared.restoreSession() {
                currentUserName = user.displayName
                activeUserEmail = user.email
                isAuthenticated = true
            }
        }
    }
}

#Preview("Welcome") {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Home") {
    AppShell(
        isAuthenticated: .constant(true),
        authRoute: .constant(.login),
        userName: "Nilupul"
    )
}
