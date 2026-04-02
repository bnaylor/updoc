import SwiftUI

struct ContentView: View {
    @State private var editorText = "# Welcome to updoc\n\nStart typing your meeting notes here."
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            EditorView(text: $editorText)
        }
    }
}
