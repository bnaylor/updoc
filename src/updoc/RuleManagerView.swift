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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IF \(rule.attribute.rawValue) contains \"\(rule.pattern)\"")
                            .font(.headline)
                        Text("THEN apply template")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
