# Research: Google Docs Checklist Mystery

During the implementation of Google Docs import for checklists, we discovered a significant limitation in the Google Docs API regarding the "checked" state of checklist items.

## Observation

In the Google Docs UI, action items are rendered as interactive checkboxes. Some of these items were checked, while others were not.

However, when fetching the document source via the Google Docs API, the raw JSON payload did not contain any direct indication of the checked state for those specific items.

## Findings

1.  **Identification of Checklists**: Checklists can be identified by the presence of `GLYPH_TYPE_UNSPECIFIED` in the `listProperties` for a specific `listId`. This distinguishes them from standard bullet or numbered lists.
2.  **Checked State in Text Runs**: In some cases, Google Docs applies `strikethrough: true` to the text runs of a completed checklist item. Our code now checks for this and renders those items as `[x]`.
3.  **The Mystery**: For the action items we inspected, the API response returned an empty `textStyle: {}` for the text runs, even though the items appeared checked in the UI. No other property in the `bullet` or `paragraphStyle` indicated the completed state.

## Current Implementation

We use a heuristic approach:
-   If `glyphType == "GLYPH_TYPE_UNSPECIFIED"`, we identify the item as a checkbox.
-   We scan the text runs of the paragraph. If any text run has `strikethrough: true`, we render it as checked (`[x]`). Otherwise, it defaults to unchecked (`[ ]`).

## Future Follow-up

-   Investigate if newer versions of the Google Docs API expose this state more explicitly (e.g., a `checklist` object).
-   Check if there are hidden or undocumented properties in the payload that represent the state.
