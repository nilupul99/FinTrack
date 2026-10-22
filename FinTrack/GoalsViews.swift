import SwiftUI

struct GoalsScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Goals Yet",
                systemImage: "target",
                description: Text("Goals will appear here when you create them.")
            )
            .navigationTitle("Goals")
        }
    }
}
