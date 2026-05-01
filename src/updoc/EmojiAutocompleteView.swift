import SwiftUI

struct EmojiAutocompleteView: View {
    let matches: [EmojiMatch]
    let selectedIndex: Int?
    let onSelect: (EmojiMatch) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<matches.count, id: \.self) { index in
                    let match = matches[index]
                    HStack {
                        Text(match.shortcode)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Text(match.emoji)
                            .font(.system(size: 18))
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(match)
                    }
                    Divider()
                }
            }
        }
        .frame(width: 200, height: 200)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
