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
            builder.add(node.from, node.to, hiddenDeco)
          }
        },
      })

      return builder.finish()
    }
  },
  { decorations: (v) => v.decorations }
)

export const syntaxHidingTheme = EditorView.baseTheme({
  ".cm-updoc-hidden": { display: "none" },
})
