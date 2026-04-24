import SwiftUI
import SwiftData

struct RuleManagerView: View {
    @Query private var rules: [TemplateRule]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var showNavigation: Bool = true
    var onAddRule: () -> Void
    
    var body: some View {
        Group {
            if showNavigation {
                NavigationStack {
                    contentView
                }
            } else {
                contentView
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            print("RuleManagerView appeared. Rules count: \(rules.count)")
            do {
                let descriptor = FetchDescriptor<TemplateRule>()
                let fetchedRules = try modelContext.fetch(descriptor)
                print("Manually fetched rules count: \(fetchedRules.count)")
            } catch {
                print("Failed to fetch rules manually: \(error.localizedDescription)")
            }
        }
    }
    
    private var contentView: some View {
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onAddRule) {
                    Label("Add Rule", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            
            List {
                ForEach(rules) { rule in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(Color.accentColor)
                            
                            Text("Rule")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                if let index = rules.firstIndex(where: { $0.id == rule.id }) {
                                    modelContext.delete(rules[index])
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        
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
                            .frame(width: 150)
                            
                            if rule.attribute == .participantCount {
                                Picker("", selection: Binding(
                                    get: {
                                        if rule.pattern.hasPrefix(">") { return ">" }
                                        if rule.pattern.hasPrefix("<") { return "<" }
                                        return "=="
                                    },
                                    set: { newOp in
                                        let value = rule.pattern.hasPrefix(">") || rule.pattern.hasPrefix("<") ? String(rule.pattern.dropFirst()) : rule.pattern
                                        if newOp == "==" {
                                            rule.pattern = value
                                        } else {
                                            rule.pattern = newOp + value
                                        }
                                    }
                                )) {
                                    Text("is equal to").tag("==")
                                    Text("is greater than").tag(">")
                                    Text("is less than").tag("<")
                                }
                                .pickerStyle(.menu)
                                .frame(width: 130)
                                
                                TextField("Count", text: Binding(
                                    get: {
                                        let pattern = rule.pattern
                                        if pattern.hasPrefix(">") || pattern.hasPrefix("<") {
                                            return String(pattern.dropFirst())
                                        }
                                        return pattern
                                    },
                                    set: { newValue in
                                        let pattern = rule.pattern
                                        let op = pattern.hasPrefix(">") ? ">" : (pattern.hasPrefix("<") ? "<" : "")
                                        rule.pattern = op + newValue
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            } else {
                                Text("contains")
                                    .foregroundStyle(.secondary)
                                
                                TextField("Pattern (e.g., 1:1)", text: Binding(
                                    get: { rule.pattern },
                                    set: { rule.pattern = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        HStack {
                            Text("Theme:")
                                .font(.subheadline)
                            
                            Picker("", selection: Binding(
                                get: { rule.themeName ?? "Default" },
                                set: { rule.themeName = $0 == "Default" ? nil : $0 }
                            )) {
                                Text("Default").tag("Default")
                                ForEach(AppTheme.allCases) { theme in
                                    Text(theme.rawValue).tag(theme.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("THEN apply markdown template:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            TextEditor(text: Binding(
                                get: { rule.templateContent },
                                set: { rule.templateContent = $0 }
                            ))
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 100)
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .clipShape(.rect(cornerRadius: 4))
                            .border(Color.secondary.opacity(0.2))
                        }
                        
                        Text("Variables: {{title}}, {{date}}, {{location}}, {{description}}, {{attendees}}")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    .clipShape(.rect(cornerRadius: 8))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Template Rules")
        }
    }
    
    private func addDefaultRule() {
        let newRule = TemplateRule(attribute: .title, pattern: "1:1", templateContent: "# 1:1 w/ {{title}}\n\n## Discussion\n- ")
        modelContext.insert(newRule)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save rule: \(error.localizedDescription)")
        }
    }
    
    private func deleteRules(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rules[index])
        }
    }
}
