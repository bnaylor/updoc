# updoc Markdown Reference

This document serves as the official reference for the Markdown syntax supported by `updoc`. It is used by the local editor for syntax highlighting and by the Google Docs integration for formatting translation.

## Headings
Use `#` followed by a space to create headings. Levels 1 through 6 are supported.

```markdown
# Heading 1
## Heading 2
### Heading 3
```

## Inline Styles
Standard Markdown markers for emphasis and code.

| Style | Syntax | Notes |
| :--- | :--- | :--- |
| **Bold** | `**text**` | |
| **Italic** | `*text*` | |
| **Code** | `` `text` `` | Rendered as monospaced text |
| **Link** | `[label](url)` | |

## Task Management
`updoc` includes built-in support for checklists and task promotion.

| Syntax | Description |
| :--- | :--- |
| `[ ] Task` | Uncompleted task |
| `[x] Task` | Completed task (rendered with strikethrough) |
| `√` | Shortcut: Typing `√` at the start of a line auto-converts to `[ ]` |

## Images & Assets
`updoc` supports both remote images and locally managed assets.

| Syntax | Type | Description |
| :--- | :--- | :--- |
| `![alt](url)` | Remote | Standard Markdown image |
| `![[id]]` | Local | Internal asset from the image library |

## Google Docs Integration
When syncing to Google Docs:
- Markdown markers (`**`, `#`, etc.) are stripped.
- Native Google Docs styles (e.g., `HEADING_1`, `Bold`) are applied.
- Links and images are embedded natively.
