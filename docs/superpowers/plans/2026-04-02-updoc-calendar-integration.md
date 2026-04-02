# updoc Calendar Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Google Calendar sync, a collapsible sidebar meeting browser, and a smart template engine for frictionless note-starting.

**Architecture:** A `GCalendarService` actor fetches events via the Google REST API. A `SmartTemplateEngine` matches these events against `TemplateRule` models (stored in SwiftData) to pre-fill notes and auto-link Google Docs.

**Tech Stack:** Swift 6.0, Google Calendar REST API, SwiftUI, SwiftData.

---

### Task 1: GCalendarService & Event Fetching

**Files:**
- Create: `src/updoc/GCalendarService.swift`
- Test: `tests/updocTests/CalendarServiceTests.swift`

- [ ] **Step 1: Define GCalendarService actor**

```swift
import Foundation

public struct CalendarEvent: Codable, Identifiable, Sendable {
    public let id: String
    public let summary: String
    public let description: String?
    public let location: String?
    public let start: Date
    public let attendees: [String]
}

public actor GCalendarService {
    public static let shared = GCalendarService()
    
    public func fetchTodaysEvents() async throws -> [CalendarEvent] {
        // TODO: Implement Google Calendar API call (for now return mock)
        return [
            CalendarEvent(id: "1", summary: "updoc Architecture Sync", description: "Design sync", location: "g.co/doc/abc", start: .now, attendees: ["bnaylor@google.com", "gemini@google.com"])
        ]
    }
}
```

- [ ] **Step 2: Create a test for event fetching**

```swift
// tests/updocTests/CalendarServiceTests.swift
import Testing
import Foundation
@testable import updoc

struct CalendarServiceTests {
    @Test func canFetchMockEvents() async throws {
        let service = GCalendarService.shared
        let events = try await service.fetchTodaysEvents()
        #expect(events.count > 0)
        #expect(events.first?.summary == "updoc Architecture Sync")
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/updoc/GCalendarService.swift tests/updocTests/CalendarServiceTests.swift
git commit -m "feat: add GCalendarService for fetching meeting data"
```

---

### Task 2: TemplateRule Model & SmartTemplateEngine

**Files:**
- Create: `src/updoc/TemplateRule.swift`
- Create: `src/updoc/SmartTemplateEngine.swift`
- Test: `tests/updocTests/TemplateEngineTests.swift`

- [ ] **Step 1: Define TemplateRule model**

```swift
import Foundation
import SwiftData

@Model
public class TemplateRule {
    public var id: UUID
    public var attribute: String // "Title", "Participant"
    public var pattern: String
    public var templateContent: String
    
    public init(attribute: String, pattern: String, templateContent: String) {
        self.id = UUID()
        self.attribute = attribute
        self.pattern = pattern
        self.templateContent = templateContent
    }
}
```

- [ ] **Step 2: Implement SmartTemplateEngine**

```swift
import Foundation

public struct SmartTemplateEngine {
    public init() {}
    
    public func resolveTemplate(for event: CalendarEvent, rules: [TemplateRule]) -> String {
        for rule in rules {
            if rule.attribute == "Title" && event.summary.contains(rule.pattern) {
                return apply(template: rule.templateContent, to: event)
            }
        }
        return "# \(event.summary)\n\nDate: \(event.start.formatted())\n\n## Notes\n- "
    }
    
    private func apply(template: String, to event: CalendarEvent) -> String {
        return template
            .replacingOccurrences(of: "{{title}}", with: event.summary)
            .replacingOccurrences(of: "{{date}}", with: event.start.formatted())
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/updoc/TemplateRule.swift src/updoc/SmartTemplateEngine.swift
git commit -m "feat: add TemplateRule model and SmartTemplateEngine"
```

---

### Task 3: Sidebar UI Integration (Calendar Section)

**Files:**
- Modify: `src/updoc/SidebarView.swift`
- Modify: `src/updoc/ContentView.swift`

- [ ] **Step 1: Update SidebarView with Meeting List**

```swift
// SidebarView.swift (Update)
@State private var meetings: [CalendarEvent] = []

Section("TODAY'S MEETINGS") {
    ForEach(meetings) { meeting in
        VStack(alignment: .leading) {
            Text(meeting.summary).font(.subheadline).bold()
            Text(meeting.start.formatted(date: .omitted, time: .shortened)).font(.caption)
            Button("Start Note") {
                startNote(for: meeting)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
.onAppear {
    Task {
        meetings = try? await GCalendarService.shared.fetchTodaysEvents() ?? []
    }
}
```

- [ ] **Step 2: Implement startNote logic**

- [ ] **Step 3: Commit**

```bash
git add src/updoc/SidebarView.swift
git commit -m "feat: integrate meeting browser into sidebar"
```

---

### Task 4: Template Rule Manager UI

**Files:**
- Create: `src/updoc/RuleManagerView.swift`
- Modify: `src/updoc/updocApp.swift`

- [ ] **Step 1: Create RuleManagerView**

```swift
import SwiftUI
import SwiftData

struct RuleManagerView: View {
    @Query private var rules: [TemplateRule]
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List {
            ForEach(rules) { rule in
                VStack(alignment: .leading) {
                    Text("IF \(rule.attribute) Contains \"\(rule.pattern)\"")
                    Text("THEN Apply Template").font(.caption).foregroundColor(.secondary)
                }
            }
            .onDelete(perform: deleteRules)
        }
        .navigationTitle("Template Rules")
        .toolbar {
            Button("Add Rule", systemImage: "plus") {
                addDefaultRule()
            }
        }
    }
    
    private func addDefaultRule() {
        let newRule = TemplateRule(attribute: "Title", pattern: "1:1", templateContent: "# 1:1 w/ {{title}}\n\n## Discussion\n- ")
        modelContext.insert(newRule)
    }
    
    private func deleteRules(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rules[index])
        }
    }
}
```

- [ ] **Step 2: Add Settings/Rules link to App menu or Sidebar**

- [ ] **Step 3: Commit**

```bash
git add src/updoc/RuleManagerView.swift
git commit -m "feat: add Template Rule Manager UI"
```
