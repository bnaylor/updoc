import SwiftUI
import SwiftData

struct AutocompleteItem: Identifiable {
    let id = UUID()
    let match: AutocompleteMatch
}

struct ContactAutocompleteView: View {
    let items: [AutocompleteItem]
    let selectedIndex: Int
    let onSelect: (AutocompleteMatch) -> Void
    let onAddNewContact: () -> Void
    
    var body: some View {
        let selectedItemId = selectedIndex < items.count ? items[selectedIndex].id : nil
        
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(items, id: \.id) { (item: AutocompleteItem) in
                HStack {
                    VStack(alignment: .leading) {
                        switch item.match {
                        case .person(let person):
                            Text(person.name)
                                .font(.headline)
                            Text(person.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        case .date(let date):
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.headline)
                            Text("Date")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(item.id == selectedItemId ? Color.accentColor.opacity(0.2) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(item.match)
                }
                Divider()
            }
            
            HStack {
                Image(systemName: "person.badge.plus")
                    .foregroundStyle(Color.accentColor)
                Text("Add New Contact...")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                onAddNewContact()
            }
        }
        .frame(width: 250)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
