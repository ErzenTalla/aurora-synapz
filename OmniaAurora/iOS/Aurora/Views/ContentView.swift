import SwiftUI

struct ContentView: View {
    @StateObject private var speech = SpeechService()

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }

            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }

            WorkspaceView()
                .tabItem { Label("Workspace", systemImage: "checklist") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .environmentObject(speech)
        .tint(Theme.gold)
    }
}

#Preview {
    ContentView()
}
