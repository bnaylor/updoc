import SwiftUI
import SwiftData

struct FilterManagerView: View {
    @Query private var rules: [MeetingFilterRule]
    @Environment(\.modelContext) private var modelContext
    
    var onAddFilterRule: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onAddFilterRule) {
                    Label("Add Filter Rule", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            
            List {
                if rules.isEmpty {
                    Text("No filter rules defined yet.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(rules) { rule in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("Rule")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    modelContext.delete(rule)
                                    try? modelContext.save()
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            TextField("Title contains", text: Binding(
                                get: { rule.titlePattern ?? "" },
                                set: { rule.titlePattern = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            
                            TextField("Description contains", text: Binding(
                                get: { rule.descriptionPattern ?? "" },
                                set: { rule.descriptionPattern = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            
                            TextField("Participant email", text: Binding(
                                get: { rule.participantPattern ?? "" },
                                set: { rule.participantPattern = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            
                            Picker("Event Type", selection: Binding(
                                get: { rule.eventType ?? "" },
                                set: { rule.eventType = $0.isEmpty ? nil : $0 }
                            )) {
                                Text("All Types").tag("")
                                Text("Event").tag("default")
                                Text("Focus Time").tag("focusTime")
                                Text("Out of Office").tag("outOfOffice")
                                Text("Working Location").tag("workingLocation")
                                Text("Birthday").tag("birthday")
                                Text("Generated from Gmail").tag("fromGmail")
                            }
                            .pickerStyle(.menu)
                            
                            Toggle("All Day Only", isOn: Binding(
                                get: { rule.isAllDay ?? false },
                                set: { rule.isAllDay = $0 }
                            ))
                        }
                        .padding(.vertical, 8)
                    }
                    .onDelete(perform: deleteRules)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rules[index])
        }
        try? modelContext.save()
    }
}
