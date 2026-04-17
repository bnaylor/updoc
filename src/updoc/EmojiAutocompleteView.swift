import SwiftUI

struct EmojiAutocompleteView: View {
    let matches: [EmojiMatch]
    let selectedIndex: Int?
    let onSelect: (EmojiMatch) -> Void
    
    var body: some View {
        List(0..<matches.count, id: \.self) { index in
            let match = matches[index]
            HStack {
                Text(match.shortcode)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Text(match.emoji)
                    .font(.system(size: 18))
            }
            .contentShape(Rectangle())
            .listRowBackground(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
            .onTapGesture {
                onSelect(match)
            }
        }
        .listStyle(.plain)
        .frame(width: 200, height: 150)
    }
}
