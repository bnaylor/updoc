# Design Spec: Moma/Directory Integration

**Date:** 2026-04-03
**Status:** Approved
**Topic:** Real internal directory lookups for @mentions.

---

## 1. Goals
- Replace mock `MomaService` data with real REST API calls to the internal directory.
- Implement debounced searching in `AutocompleteManager` to prevent overwhelming the API.
- Ensure `@mention` chips in the editor are tied to real user data.
- Provide a responsive and reliable person lookup experience.

---

## 2. Architecture

### A. MomaService (Actor)
- **Responsibility:** Executing REST calls against the internal directory API.
- **Pattern:** `URLSession` + `Codable`.
- **Configuration:** Reads `MOMA_API_URL` and `MOMA_API_KEY` (or similar) from the `.env` file via `Config.swift`.
- **Interface:** `searchPeople(query: String) async throws -> [Person]`.

### B. AutocompleteManager
- **Responsibility:** Coordinating results from multiple sources (Moma, Dates).
- **Optimization:** Debounce logic (wait 300ms) to ensure only stable queries are sent to the network.
- **Caching:** Implement a simple in-memory cache for recent successful lookups.

### C. Editor Integration
- **Mechanism:** Detect `@` keypress in `EditorView.Coordinator`.
- **UI:** Render matching `Person` objects in a native `NSMenu` for selection.
- **Chips:** Selected people are inserted as styled "chips" in the editor.

---

## 3. Implementation Plan (High Level)
1. Update `Config.swift` and `.env.template` for Moma API details.
2. Implement real `MomaService.searchPeople` using `URLSession`.
3. Add debouncing and caching to `AutocompleteManager`.
4. Refine the autocomplete UI in `EditorView` to handle network delays gracefully (e.g., loading states).
5. Verify with integration tests using a mock server or test environment.

---

## 4. Security & Error Handling
- **API Keys:** Sensitive credentials must stay in `.env` and never be committed.
- **Fail-Safe:** If the Moma API is unreachable, the system should fail gracefully (e.g., show "No results" or a local fallback).
- **Privacy:** Ensure no sensitive person data is logged or transmitted unnecessarily.
