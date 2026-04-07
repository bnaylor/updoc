# Design: WriteControl and Seamless Conflict Resolution in `updoc`

This document outlines the design for implementing Google Docs `WriteControl` and a 3-way merge strategy to handle concurrent edits in `updoc`.

## Objective
To ensure that `updoc` does not accidentally overwrite changes made by other users in Google Docs, and to provide a "seamless" merge experience (similar to `git rebase` or Google Docs' native collaborative editing) when conflicts occur.

## Architecture Changes

### 1. Model Updates (`GDocsModels.swift`)

We need to update our models to support tracking document versions and specifying write constraints.

- **`GDocsDocument`**: Add `revisionId: String` to the root model.
- **`GDocsWriteControl`**: A new struct for the `batchUpdate` request.
  ```swift
  public struct GDocsWriteControl: Codable {
      public let requiredRevisionId: String?
  }
  ```
- **`GDocsBatchUpdateRequest`**: Add `writeControl: GDocsWriteControl?` to the request body.

### 2. Service Interface Changes (`GDocsService.swift`)

- **`fetchDocContent(docId:)`**: Instead of returning just a `String`, it will now return a `GDocsDocument` (which contains the `revisionId` and the full body structure).
- **`updateDocContent(docId:content:baseDocument:...)`**: Takes the `baseDocument` representing the state of the document when it was last fetched by the caller.

## Conflict Resolution Strategy: The "Rebase" Workflow

When `updoc` attempts to update a document, it will follow this lifecycle:

### Phase 1: Diff Generation
Instead of a full-document replacement ("delete everything, insert everything"), `updoc` will:
1. Compare the **`baseDocument`** (last known state) with the **`newLocalContent`** (intended state).
2. Generate a list of minimal `GDocsRequest` objects (insertions and deletions) that transform the base document into the new state.

### Phase 2: Attempted Update with `WriteControl`
1. Send the `batchUpdate` request including `WriteControl(requiredRevisionId: baseDocument.revisionId)`.
2. **Success**: If the `revisionId` matches, the changes are applied atomically.
3. **Conflict (400 Bad Request)**: If the `revisionId` is outdated (someone else edited the doc):
   - **Fetch Latest**: Re-fetch the current document from the server (**`remoteDocument`**).
   - **3-Way Merge**: Attempt to "rebase" our local changes onto the `remoteDocument`.
     - If our local changes and the remote changes are in different parts of the document, the merge is automatic.
     - If they overlap, a "last-writer-wins" or "append" strategy will be used for the conflicting range.
   - **Retry**: Generate a new `batchUpdate` using the `remoteDocument.revisionId` as the new `requiredRevisionId`.

### Phase 3: Recursive Protection and Backoff
To prevent infinite loops while maintaining the "seamless" promise:
1. **Retry Limit**: The loop will attempt up to 5 retries.
2. **Exponential Backoff**: If a conflict persists, `updoc` will introduce a short, increasing delay between retries (e.g., 500ms, 1s, 2s) to allow the "edit storm" to settle.
3. **User Notification**: If the limit is reached, `updoc` will output a message:
   > "Conflict resolution is taking longer than expected due to high activity on this document. Retrying in a moment... (Attempt X/5)"
4. **Final Failure**: If all 5 attempts fail, `updoc` will exit with a specific error code and instructions:
   > "Error: Document is under heavy concurrent use. Please wait a moment and try your update again, or check the document in the browser. (Final Revision ID: [ID])"

## Testing Strategy
- **Unit Tests**: Mock `GDocsService` to simulate `400 Bad Request` (outdated revision) and verify the retry/rebase logic.
- **Integration Tests**: Perform concurrent updates on a test document to ensure `WriteControl` correctly blocks outdated writes and the rebase logic successfully merges changes.

## Success Criteria
- `updoc` successfully detects when a document has changed since its last fetch.
- Concurrent edits by other users are preserved whenever possible.
- The user experience remains "seamless" without manual conflict resolution for non-overlapping changes.
