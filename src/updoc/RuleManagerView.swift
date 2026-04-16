import SwiftUI
import SwiftData

struct RuleManagerView: View {
    @Query private var rules: [TemplateRule]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(rules) { rule in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Picker("IF", selection: Binding(
                                get: { rule.attribute },
                                set: { rule.attribute = $0 }
                            )) {
                                ForEach(RuleAttribute.allCases, id: \.self) { attr in
                                    Text(attr.rawValue).tag(attr)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 140)
                            
                            Text("contains")
                                .foregroundColor(.secondary)
                            
                            TextField("Pattern (e.g., 1:1)", text: Binding(
                                get: { rule.pattern },
                                set: { rule.pattern = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("THEN apply markdown template:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: Binding(
                                get: { rule.templateContent },
                                set: { rule.templateContent = $0 }
                            ))
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 80)
                            .border(Color.secondary.opacity(0.2))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteRules)
            }
            .navigationTitle("Template Rules")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addDefaultRule) {
                        Label("Add Rule", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func addDefaultRule() {
        let newRule = TemplateRule(attribute: .title, pattern: "1:1", templateContent: "# 1:1 w/ {{title}}\n\n## Discussion\n- ")
        modelContext.insert(newRule)
    }
    
    private func deleteRules(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rules[index])
        }
    }
}
