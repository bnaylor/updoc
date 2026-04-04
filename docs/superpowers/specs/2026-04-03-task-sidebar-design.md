# Design Spec: Task Sidebar

**Date:** 2026-04-03
**Status:** Approved
**Topic:** Global action item management in a dedicated sidebar.

---

## 1. Goals
- Provide a unified, global view of all `ActionItems` across all notes.
- Implement a 3-column `NavigationSplitView` (Sidebar - Editor - Tasks).
- Allow users to sort and filter tasks by due date and status.
- Enable quick navigation from a task to its source note.

---

## 2. User Experience

### A. Right Sidebar Layout
- A collapsible third column on the right side of the main window.
- Header with "TASKS" title and a simple search/filter bar.
- List of tasks grouped by relative time: "OVERDUE", "TODAY", "UPCOMING", "NO DUE DATE".
- Completed tasks are optionally hidden or moved to a "DONE" section.

### B. Task Item Components
- **Checkbox:** Toggle status between `TODO` and `DONE`.
- **Title:** The name of the action item.
- **Due Date:** Visual indicator (e.g., red for overdue, yellow for today).
- **Note Link:** Small text showing the title of the note where the task originated. Clicking this selects the note in the main navigation.

### C. Interactions
- **Context Menu:** Right-click a task to change its status, assignee, or due date.
- **Sync:** Changes made in the sidebar immediately reflect in the source note's Markdown (and vice-versa).

---

## 3. Architecture

### A. TaskSidebarView (New Component)
- **Responsibility:** Rendering the list of tasks and handling global task actions.
- **State:** Uses `@Query` to fetch all `ActionItem` objects from SwiftData.
- **Logic:** Performs client-side grouping and sorting.

### B. Navigation & Selection
- Update `ContentView` to manage the visibility state of the third column.
- Use a shared `selectedNote` binding to allow the sidebar to trigger navigation.

### C. Live Update Mechanism
- Since `ActionItem` is a SwiftData `@Model` and is linked to `Note`, updates to its properties (like status) will automatically trigger UI refreshes in both the sidebar and the editor (if the note is open).

---

## 4. Implementation Plan (High Level)
1. Modify `ContentView` to support a 3-column `NavigationSplitView`.
2. Create `TaskSidebarView` with a basic `@Query` for all `ActionItem`s.
3. Build the task list UI with grouping and sorting logic.
4. Implement navigation from sidebar items to the editor.
5. Add a toolbar button to toggle the task sidebar visibility.

---

## 5. Constraints & Considerations
- **Performance:** For very large vaults (thousands of tasks), we may need to optimize the query or use a more efficient grouping strategy.
- **Visual Balance:** Ensure the 3-column layout doesn't feel cramped on smaller screens (provide a minimum width for the editor).
- **Editor Sync:** Ensure that toggling a checkbox in the sidebar correctly updates the Markdown string in the source note (this might require a helper method to find and replace the checkbox in the content).
