import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("FinTrack")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Track your finances with ease")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
