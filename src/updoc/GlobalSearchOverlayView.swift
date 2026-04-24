import SwiftUI

public struct GlobalSearchOverlayView: View {
    @Binding var isVisible: Bool
    let notes: [Note]
    let onResultSelect: (Note, SearchSnippet?) -> Void
    
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var flattenedResults: [FlatSearchResult] = []
    @State private var selectedIndex = 0
    @State private var tagSuggestions: [String] = []
    @State private var selectedTagIndex = 0
    @FocusState private var isFocused: Bool
    
    private let searchEngine = SearchEngine()
    private let tagManager = TagManager()
    
    public init(isVisible: Binding<Bool>, notes: [Note], onResultSelect: @escaping (Note, SearchSnippet?) -> Void) {
        self._isVisible = isVisible
        self.notes = notes
        self.onResultSelect = onResultSelect
    }
    
    public var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isVisible = false
                }
            
            VStack(spacing: 0) {
                // Search Header
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    TextField("Search notes, snippets, and #tags...", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title2)
                        .focused($isFocused)
                        .onChange(of: query) { _, newValue in
                            updateSearch(query: newValue)
                        }
                    
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("Esc")
                        .font(.caption)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(.rect(cornerRadius: 4))
                        .foregroundStyle(.secondary)
                }
                .padding()
                
                Divider()
                
                // Content Area
                ZStack(alignment: .topLeading) {
                    if !tagSuggestions.isEmpty {
                        tagSuggestionsList
                    } else if !results.isEmpty {
                        resultsList
                    } else if !query.isEmpty {
                        noResultsView
                    } else {
                        recentNotesView
                    }
                }
                .frame(maxHeight: 400)
            }
            .background(Color(NSColor.windowBackgroundColor))
            .clipShape(.rect(cornerRadius: 12))
            .shadow(radius: 20)
            .frame(width: 600)
            .onAppear {
                isFocused = true
            }
        }
        .onExitCommand {
            isVisible = false
        }
        .onKeyPress(.downArrow) {
            handleDownArrow()
            return .handled
        }
        .onKeyPress(.upArrow) {
            handleUpArrow()
            return .handled
        }
        .onKeyPress(.return) {
            handleReturn()
            return .handled
        }
    }
    
    private var resultsList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(results) { result in
                    Section(header: Text(result.note.title).font(.headline).foregroundStyle(.primary)) {
                        if result.snippets.isEmpty {
                            FlatResultRow(
                                note: result.note,
                                snippet: nil,
                                query: query,
                                isSelected: isSelected(note: result.note, snippet: nil)
                            ) {
                                onResultSelect(result.note, nil)
                                isVisible = false
                            }
                            .id(flatIndex(note: result.note, snippet: nil))
                        } else {
                            ForEach(result.snippets) { snippet in
                                FlatResultRow(
                                    note: result.note,
                                    snippet: snippet,
                                    query: query,
                                    isSelected: isSelected(note: result.note, snippet: snippet)
                                ) {
                                    onResultSelect(result.note, snippet)
                                    isVisible = false
                                }
                                .id(flatIndex(note: result.note, snippet: snippet))
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: selectedIndex) { _, newIndex in
                proxy.scrollTo(newIndex, anchor: .center)
            }
        }
    }
    
    private var tagSuggestionsList: some View {
        List(Array(tagSuggestions.enumerated()), id: \.offset) { index, tag in
            HStack {
                Text("#\(tag)")
                    .font(.body)
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(selectedTagIndex == index ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(.rect(cornerRadius: 4))
            .contentShape(Rectangle())
            .onTapGesture {
                applyTagSuggestion(tag)
            }
        }
        .listStyle(.plain)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
        .shadow(radius: 5)
        .frame(maxWidth: 200)
        .padding(8)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No results found for \"\(query)\"")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var recentNotesView: some View {
        VStack(alignment: .leading) {
            Text("Recent Notes")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top)
            
            List(notes.prefix(5)) { note in
                Button {
                    onResultSelect(note, nil)
                    isVisible = false
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text(note.title)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
            .listStyle(.plain)
        }
    }
    
    // MARK: - Search Logic
    
    private func updateSearch(query: String) {
        if let tagQuery = extractTagQuery(from: query) {
            tagSuggestions = tagManager.getAllTags(in: notes).filter { $0.localizedCaseInsensitiveContains(tagQuery) || tagQuery.isEmpty }
            results = []
            flattenedResults = []
        } else {
            tagSuggestions = []
            results = searchEngine.search(query: query, in: notes)
            updateFlattenedResults()
        }
        selectedIndex = 0
        selectedTagIndex = 0
    }
    
    private func extractTagQuery(from query: String) -> String? {
        if query.starts(with: "#") {
            return String(query.dropFirst())
        }
        if let range = query.range(of: " #", options: .backwards) {
            return String(query[range.upperBound...])
        }
        return nil
    }
    
    private func updateFlattenedResults() {
        var flat: [FlatSearchResult] = []
        for result in results {
            if result.snippets.isEmpty {
                flat.append(FlatSearchResult(note: result.note, snippet: nil))
            } else {
                for snippet in result.snippets {
                    flat.append(FlatSearchResult(note: result.note, snippet: snippet))
                }
            }
        }
        flattenedResults = flat
    }
    
    private func flatIndex(note: Note, snippet: SearchSnippet?) -> Int {
        flattenedResults.firstIndex { $0.note.id == note.id && $0.snippet?.id == snippet?.id } ?? -1
    }
    
    private func isSelected(note: Note, snippet: SearchSnippet?) -> Bool {
        guard selectedIndex >= 0 && selectedIndex < flattenedResults.count else { return false }
        let current = flattenedResults[selectedIndex]
        return current.note.id == note.id && current.snippet?.id == snippet?.id
    }
    
    // MARK: - Event Handlers
    
    private func handleDownArrow() {
        if !tagSuggestions.isEmpty {
            selectedTagIndex = (selectedTagIndex + 1) % tagSuggestions.count
        } else if !flattenedResults.isEmpty {
            selectedIndex = (selectedIndex + 1) % flattenedResults.count
        }
    }
    
    private func handleUpArrow() {
        if !tagSuggestions.isEmpty {
            selectedTagIndex = (selectedTagIndex - 1 + tagSuggestions.count) % tagSuggestions.count
        } else if !flattenedResults.isEmpty {
            selectedIndex = (selectedIndex - 1 + flattenedResults.count) % flattenedResults.count
        }
    }
    
    private func handleReturn() {
        if !tagSuggestions.isEmpty {
            applyTagSuggestion(tagSuggestions[selectedTagIndex])
        } else if !flattenedResults.isEmpty {
            let selected = flattenedResults[selectedIndex]
            onResultSelect(selected.note, selected.snippet)
            isVisible = false
        }
    }
    
    private func applyTagSuggestion(_ tag: String) {
        if query.starts(with: "#") {
            query = "#\(tag) "
        } else if let range = query.range(of: " #", options: .backwards) {
            query = String(query[..<range.lowerBound]) + " #\(tag) "
        }
        updateSearch(query: query)
        isFocused = true
    }
}

// MARK: - Supporting Types

struct FlatSearchResult: Identifiable {
    let id = UUID()
    let note: Note
    let snippet: SearchSnippet?
}

struct FlatResultRow: View {
    let note: Note
    let snippet: SearchSnippet?
    let query: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                if let snippet = snippet {
                    highlightedText(snippet.text, matchRange: snippet.matchRange)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                } else {
                    Text("Matched in title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
    
    private func highlightedText(_ text: String, matchRange: NSRange) -> Text {
        guard let range = Range(matchRange, in: text) else {
            return Text(text)
        }
        
        let prefix = String(text[..<range.lowerBound])
        let match = String(text[range])
        let suffix = String(text[range.upperBound...])
        
        return Text(prefix) +
               Text(match).fontWeight(.bold).foregroundStyle(Color.accentColor) +
               Text(suffix)
    }
}

#Preview {
    @Previewable @State var isVisible = true
    return GlobalSearchOverlayView(isVisible: $isVisible, notes: []) { _, _ in }
}
