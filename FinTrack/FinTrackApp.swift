//
//  FinTrackApp.swift
//  FinTrack
//
//  Created by Nilupul Rambukwelle on 2026-10-10.
//

import SwiftUI
import CoreData

@main
struct FinTrackApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .task {
                    await NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
