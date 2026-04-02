import SwiftUI

struct SidebarView: View {
    var body: some View {
        List {
            Section("MEETINGS") {
                Text("Today (Apr 2)")
                Text("- 1:1 w/ Duckie")
            }
            Section("TOPICS") {
                Text("updoc Project")
                Text("Research")
            }
        }
        .listStyle(.sidebar)
    }
}
