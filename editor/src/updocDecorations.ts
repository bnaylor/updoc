import {
  EditorView, Decoration, DecorationSet, WidgetType, ViewPlugin, ViewUpdate
} from "@codemirror/view"
import { RangeSetBuilder } from "@codemirror/state"
import { syntaxTree } from "@codemirror/language"

/// A zero-width invisible decoration used to hide syntax markers.
const hiddenDeco = Decoration.mark({ class: "cm-updoc-hidden" })

/// Returns the line number (1-based) that contains the primary cursor.
function cursorLine(view: EditorView): number {
  return view.state.doc.lineAt(view.state.selection.main.head).number
}

/// Node names in the Lezer markdown syntax tree whose text should be hidden
/// when the cursor is not on the same line.
const HIDEABLE_NODES = new Set([
  "EmphasisMark",       // * or _
  "StrongEmphasisMark", // ** or __
  "CodeMark",           // `
  "HeaderMark",         // # ## etc.
  "QuoteMark",          // >
  "LinkMark",           // [ ] ( )
  "LinkResource",       // (url) in [text](url)
  "URL",                // bare URL
  "HorizontalRule",     // ---
])

export const syntaxHidingPlugin = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet

    constructor(view: EditorView) {
      this.decorations = this.build(view)
    }

    update(update: ViewUpdate) {
      if (update.docChanged || update.selectionSet || update.viewportChanged) {
        this.decorations = this.build(update.view)
      }
    }

    build(view: EditorView): DecorationSet {
      const builder = new RangeSetBuilder<Decoration>()
      const activeLine = cursorLine(view)

      syntaxTree(view.state).iterate({
        enter(node) {
          if (!HIDEABLE_NODES.has(node.name)) return
          const line = view.state.doc.lineAt(node.from).number
          if (line !== activeLine) {
            let to = node.to
            // If it's a heading mark, also hide the trailing space
            if (node.name === "HeaderMark") {
              const nextChar = view.state.sliceDoc(node.to, node.to + 1)
              if (nextChar === " ") {
                to += 1
              }
            }
            builder.add(node.from, to, hiddenDeco)
          }
        }
      })

      return builder.finish()
    }
  },
  { decorations: (v) => v.decorations }
)

export const syntaxHidingTheme = EditorView.baseTheme({
  ".cm-updoc-hidden": { display: "none" },
})

const underlineMark = Decoration.mark({ class: "cm-updoc-underline" })
const highlightMark = Decoration.mark({ class: "cm-updoc-highlight" })
const pillMark = Decoration.mark({ class: "cm-updoc-pill" })

// Matches ~text~ (single tilde, not double ~~)
const UNDERLINE_RE = /(?<![~])~(?!~)(.+?)(?<![~])~(?!~)/g
// Matches ==text==
const HIGHLIGHT_RE = /==(.+?)==/g
// Matches [@Name](mailto:email)
const MENTION_RE = /\[(@.+?)\]\(mailto:.+?\)/g

export const customMarkPlugin = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet

    constructor(view: EditorView) {
      this.decorations = this.build(view)
    }

    update(update: ViewUpdate) {
      if (update.docChanged || update.viewportChanged || update.selectionSet) {
        this.decorations = this.build(update.view)
      }
    }

    build(view: EditorView): DecorationSet {
      const builder = new RangeSetBuilder<Decoration>()
      const activeLine = cursorLine(view)

      for (const { from, to } of view.visibleRanges) {
        const text = view.state.sliceDoc(from, to)

        // Standard marks (~, ==)
        for (const re of [
          { pattern: UNDERLINE_RE, deco: underlineMark },
          { pattern: HIGHLIGHT_RE, deco: highlightMark },
        ]) {
          re.pattern.lastIndex = 0
          let m: RegExpExecArray | null
          while ((m = re.pattern.exec(text)) !== null) {
            const start = from + m.index
            const end = start + m[0].length
            const line = view.state.doc.lineAt(start).number
            if (line !== activeLine) {
              const markerLen = re.deco === underlineMark ? 1 : 2
              builder.add(start,             start + markerLen, hiddenDeco)
              builder.add(end - markerLen,   end,               hiddenDeco)
              builder.add(start + markerLen, end - markerLen,   re.deco)
            }
          }
        }

        // Mentions [@Name](mailto:email) -> Render as Pill
        MENTION_RE.lastIndex = 0
        let m: RegExpExecArray | null
        while ((m = MENTION_RE.exec(text)) !== null) {
          const start = from + m.index
          const end = start + m[0].length
          const line = view.state.doc.lineAt(start).number
          
          if (line !== activeLine) {
            // Hide the [ and the ](mailto:email) part
            const openBracketEnd = start + 1
            const nameStart = start + 1
            const nameEnd = start + 1 + m[1].length
            const closeParenEnd = end
            
            builder.add(start, nameStart, hiddenDeco)
            builder.add(nameStart, nameEnd, pillMark)
            builder.add(nameEnd, end, hiddenDeco)
          }
        }
      }

      return builder.finish()
    }
  },
  { decorations: (v) => v.decorations }
)

export const customMarkTheme = EditorView.baseTheme({
  ".cm-updoc-underline": { textDecoration: "underline" },
  ".cm-updoc-highlight": {
    backgroundColor: "var(--updoc-highlight, rgba(255,255,0,0.4))",
    borderRadius: "2px",
  },
  ".cm-updoc-pill": {
    backgroundColor: "var(--updoc-accent-bg, rgba(0,112,243,0.1))",
    color: "var(--updoc-accent, #0070f3)",
    padding: "0 4px",
    borderRadius: "4px",
    fontWeight: "500",
  },
})

export class CheckboxWidget extends WidgetType {
  constructor(readonly checked: boolean) { super() }

  toDOM(): HTMLElement {
    const wrap = document.createElement("span")
    wrap.setAttribute("aria-hidden", "true")
    const box = document.createElement("input")
    box.type = "checkbox"
    box.checked = this.checked
    box.style.cursor = "pointer"
    box.style.verticalAlign = "middle"
    box.style.marginRight = "4px"
    wrap.appendChild(box)
    return wrap
  }

  ignoreEvent(event: Event): boolean {
    return false // let click events through
  }
}

export const taskListPlugin = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet

    constructor(view: EditorView) {
      this.decorations = this.build(view)
    }

    update(update: ViewUpdate) {
      if (update.docChanged || update.viewportChanged) {
        this.decorations = this.build(update.view)
      }
    }

    build(view: EditorView): DecorationSet {
      const builder = new RangeSetBuilder<Decoration>()

      for (let i = 1; i <= view.state.doc.lines; i++) {
        const line = view.state.doc.line(i)
        const text = line.text

        // Match "- [ ] " or "- [x] " at start of line (with optional leading whitespace)
        const m = text.match(/^(\s*-\s)(\[[ xX]\])(\s)/)
        if (!m) continue

        const checkboxFrom = line.from + m[1].length
        const checkboxTo   = checkboxFrom + m[2].length
        const checked      = m[2].toLowerCase() === "[x]"

        builder.add(
          checkboxFrom,
          checkboxTo,
          Decoration.replace({ widget: new CheckboxWidget(checked) })
        )
      }

      return builder.finish()
    }
  },
  { decorations: (v) => v.decorations }
)
