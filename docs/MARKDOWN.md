# Updoc Markdown Reference

This document serves as the official reference for the Markdown syntax supported by `updoc`. It is used by the local editor for syntax highlighting and by the Google Docs integration for formatting translation.

## Typography

### Headings
Use `#` followed by a space to create headings. Levels 1 through 6 are supported.

```markdown
# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6
```

### Inline Styles
Standard Markdown markers for emphasis and code, plus Updoc-specific extensions.

| Style | Syntax | Notes |
| :--- | :--- | :--- |
| **Bold** | `**text**` or `__text__` | Both syntaxes supported |
| **Italic** | `*text*` or `_text_` | Both syntaxes supported |
| **Bold & Italic** | `***text***` | Combined style |
| **Underline** | `~text~` | Single tilde |
| **Strikethrough** | `~~text~~` | Double tilde |
| **Highlight** | `==text==` | Double equals |
| **Code** | `` `text` `` | Rendered as monospaced text |
| **Link** | `[label](url)` | Clickable in editor |

Example Link: [updoc GitHub](https://github.com/user/updoc)

### Blocks

#### Code Blocks
Multiline code blocks are supported using triple backticks.

```
Multiline code fencing
is also supported.
```

#### Blockquote
> This is a blockquote.
> It can span multiple lines.

#### Horizontal Rule
Use three or more dashes on a line by themselves to create a divider:
`---`

## Lists & Tasks
`updoc` supports standard markdown bullets and task lists.

### Bullets
Use `*`, `-`, or `+` followed by a space.

```markdown
* Item 1
- Item 2
+ Item 3
```

### Checklists
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

Example Remote Image: ![Example Logo](https://example.com/logo.png)
Example Local Asset: ![[asset-id-123]]

## Google Docs Integration
When syncing to Google Docs:
- Markdown markers (`**`, `#`, etc.) are stripped.
- Native Google Docs styles (e.g., `HEADING_1`, `Bold`, `Underline`) are applied.
- Bullets and checklists are converted to native Google Docs lists.
- Completed checklists (`[x]`) receive a native strikethrough.
- Links and images are embedded natively.
