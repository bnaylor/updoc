import SwiftUI

struct MentionAutocompleteView: View {
    let items: [String]
    let onSelect: (Int) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<items.count, id: \.self) { index in
                    Text(items[index])
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(index)
                        }
                    Divider()
                }
            }
            .padding()
        }
        .frame(width: 250, height: 150)
    }
}
