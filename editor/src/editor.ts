import { EditorView, keymap } from "@codemirror/view"
import {
  syntaxHidingPlugin,
  syntaxHidingTheme,
  customMarkPlugin,
  customMarkTheme,
  taskListPlugin,
} from "./updocDecorations"
import { EditorState, Compartment } from "@codemirror/state"
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands"
import { markdown, markdownLanguage } from "@codemirror/lang-markdown"
import { GFM } from "@lezer/markdown"
import { syntaxHighlighting, HighlightStyle } from "@codemirror/language"
import { tags } from "@lezer/highlight"

function makeHighlightStyle(): HighlightStyle {
  return HighlightStyle.define([
    { tag: tags.heading1,    fontSize: "calc(var(--updoc-heading-size, 1em) * 1.8)", fontWeight: "bold",   color: "var(--updoc-heading, inherit)" },
    { tag: tags.heading2,    fontSize: "calc(var(--updoc-heading-size, 1em) * 1.6)", fontWeight: "bold",   color: "var(--updoc-heading, inherit)" },
    { tag: tags.heading3,    fontSize: "calc(var(--updoc-heading-size, 1em) * 1.3)", fontWeight: "bold",   color: "var(--updoc-heading, inherit)" },
    { tag: tags.heading4,    fontSize: "calc(var(--updoc-heading-size, 1em) * 1.1)", fontWeight: "bold",   color: "var(--updoc-heading, inherit)" },
    { tag: tags.heading5,    fontSize: "var(--updoc-heading-size, 1em)",            fontWeight: "bold",   color: "var(--updoc-heading, inherit)" },
    { tag: tags.heading6,    fontSize: "calc(var(--updoc-heading-size, 1em) * 0.9)", fontWeight: "bold",   color: "var(--updoc-heading, inherit)" },
    { tag: tags.strong,      fontWeight: "bold" },
    { tag: tags.emphasis,    fontStyle: "italic" },
    { tag: tags.strikethrough, textDecoration: "line-through" },
    { tag: tags.link,        color: "var(--updoc-link, #0070f3)", textDecoration: "underline" },
    { tag: tags.url,         color: "var(--updoc-link, #0070f3)" },
    { tag: tags.monospace,   fontFamily: "var(--updoc-code-font, 'SF Mono', monospace)", fontSize: "var(--updoc-code-size, 0.9em)", color: "var(--updoc-code, inherit)", backgroundColor: "var(--updoc-code-bg, rgba(0,0,0,0.1))", padding: "2px 4px", borderRadius: "3px" },
    { tag: tags.quote,       color: "var(--updoc-blockquote, #666)", borderLeft: "3px solid var(--updoc-blockquote, #ccc)", paddingLeft: "8px" },
    { tag: tags.processingInstruction, color: "var(--updoc-text, inherit)", opacity: "0.4" },
    { tag: tags.meta,        color: "var(--updoc-text, inherit)", opacity: "0.4" },
  ])
}

// Compartment for toggling read-only state after editor creation
const readOnlyCompartment = new Compartment()

// ─── Bridge helpers ────────────────────────────────────────────────────────────

declare global {
  interface Window {
    webkit?: { messageHandlers: Record<string, { postMessage(data: unknown): void }> }
    updoc: UpdocAPI
  }
}

interface UpdocAPI {
  loadContent(text: string): void
  insertText(text: string, from?: number, to?: number): void
  setTheme(vars: Record<string, string>): void
  scrollToRange(from: number, to: number): void
  setReadOnly(readOnly: boolean): void
}

function postMessage(name: string, payload: Record<string, unknown>): void {
  window.webkit?.messageHandlers[name]?.postMessage(payload)
}

let debounceTimer: ReturnType<typeof setTimeout> | null = null

function notifyContentChanged(view: EditorView): void {
  if (debounceTimer) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    postMessage("contentChanged", { text: view.state.doc.toString() })
  }, 300)
}

let isAutocompleteVisible = false

function checkTriggers(view: EditorView): void {
  const cursor = view.state.selection.main.head
  const line = view.state.doc.lineAt(cursor)
  const before = line.text.slice(0, cursor - line.from)
  
  // Check for @mention trigger
  const mentionMatch = before.match(/@(\w*)$/)
  if (mentionMatch) {
    isAutocompleteVisible = true
    const coords = view.coordsAtPos(cursor)
    const editorRect = view.dom.getBoundingClientRect()
    postMessage("showAutocomplete", {
      type: "mention",
      query: mentionMatch[1],
      x: (coords?.left ?? 0) - editorRect.left,
      y: (coords?.top ?? 0) - editorRect.top,
      bottom: (coords?.bottom ?? 0) - editorRect.top
    })
    return
  }
  
  // Check for emoji trigger
  const emojiMatch = before.match(/:(\w*)$/)
  if (emojiMatch) {
    isAutocompleteVisible = true
    const coords = view.coordsAtPos(cursor)
    const editorRect = view.dom.getBoundingClientRect()
    postMessage("showAutocomplete", {
      type: "emoji",
      query: emojiMatch[1],
      x: (coords?.left ?? 0) - editorRect.left,
      y: (coords?.top ?? 0) - editorRect.top,
      bottom: (coords?.bottom ?? 0) - editorRect.top
    })
    return
  }

  isAutocompleteVisible = false
  postMessage("hideAutocomplete", {})
}

// ─── Editor instance ───────────────────────────────────────────────────────────

let editor: EditorView | null = null

function createEditor(): void {
  editor = new EditorView({
    state: EditorState.create({
      doc: "",
      extensions: [
        history(),
        keymap.of([
          {
            key: "ArrowDown",
            run() {
              if (isAutocompleteVisible) {
                postMessage("autocompleteKeyEvent", { key: "ArrowDown" })
                return true
              }
              return false
            }
          },
          {
            key: "ArrowUp",
            run() {
              if (isAutocompleteVisible) {
                postMessage("autocompleteKeyEvent", { key: "ArrowUp" })
                return true
              }
              return false
            }
          },
          {
            key: "Enter",
            run() {
              if (isAutocompleteVisible) {
                postMessage("autocompleteKeyEvent", { key: "Enter" })
                return true
              }
              return false
            }
          },
          ...defaultKeymap, 
          ...historyKeymap, 
          indentWithTab
        ]),
        markdown({ base: markdownLanguage, extensions: [GFM] }),
        syntaxHighlighting(makeHighlightStyle()),
        EditorView.lineWrapping,
        EditorView.domEventHandlers({
          mousedown(event, view) {
            const target = event.target as HTMLElement
            if (target.tagName !== "INPUT" || (target as HTMLInputElement).type !== "checkbox") {
              return false
            }
            event.preventDefault()
            const pos = view.posAtCoords({ x: event.clientX, y: event.clientY }, false)
            if (pos == null) return false
            const line = view.state.doc.lineAt(pos)
            const m = line.text.match(/^(\s*-\s)(\[[ xX]\])/)
            if (!m) return false
            const from = line.from + m[1].length
            const to   = from + m[2].length
            const isChecked = m[2].toLowerCase() === "[x]"
            view.dispatch({
              changes: { from, to, insert: isChecked ? "[ ]" : "[x]" }
            })
            return true
          }
        }),
        keymap.of([
          {
            key: "√",
            run(view) {
              const cursor = view.state.selection.main.head
              const line = view.state.doc.lineAt(cursor)
              const before = view.state.sliceDoc(line.from, cursor)
              if (before.trim() === "") {
                view.dispatch({ changes: { from: cursor, insert: "- [ ] " } })
                return true
              }
              return false
            }
          }
        ]),
        syntaxHidingPlugin,
        syntaxHidingTheme,
        customMarkPlugin,
        customMarkTheme,
        taskListPlugin,
        readOnlyCompartment.of(EditorState.readOnly.of(false)),
        EditorView.updateListener.of((update) => {
          if (update.docChanged) notifyContentChanged(update.view)
          if (update.selectionSet || update.docChanged) checkTriggers(update.view)
        }),
        EditorView.theme({
          "&": {
            height: "100%",
            fontSize: "var(--updoc-font-size, 16px)",
            fontFamily: "var(--updoc-font-family, -apple-system, sans-serif)",
            color: "var(--updoc-text, currentColor)",
          },
          ".cm-scroller": { overflow: "auto" },
          ".cm-content": { 
            padding: "16px 20px", 
            caretColor: "var(--updoc-text, currentColor)",
            color: "var(--updoc-text, currentColor)",
          },
          ".cm-focused": { outline: "none" },
        }),
      ],
    }),
    parent: document.getElementById("editor")!,
  })

  // Notify Swift the editor is ready
  postMessage("contentChanged", { text: "" })
}

// ─── Public API (called from Swift via evaluateJavaScript) ────────────────────

window.updoc = {
  loadContent(text: string): void {
    if (!editor) return
    editor.dispatch({
      changes: { from: 0, to: editor.state.doc.length, insert: text },
    })
  },

  insertText(text: string, from?: number, to?: number): void {
    if (!editor) return
    const sel = editor.state.selection.main
    const start = from ?? sel.from
    const end = to ?? sel.to
    editor.dispatch({
      changes: { from: start, to: end, insert: text },
      selection: { anchor: start + text.length }
    })
    editor.focus()
  },

  getEditorView(): EditorView | null {
    return editor
  },

  setTheme(vars: Record<string, string>): void {
    const root = document.documentElement
    for (const [key, value] of Object.entries(vars)) {
      root.style.setProperty(key, value)
    }
    if (vars["--updoc-bg"]) document.body.style.backgroundColor = vars["--updoc-bg"]
    if (vars["--updoc-text"]) document.body.style.color = vars["--updoc-text"]
  },

  scrollToRange(from: number, to: number): void {
    if (!editor) return
    editor.dispatch({
      selection: { anchor: from, head: to },
      effects: EditorView.scrollIntoView(from, { y: "center" }),
    })
  },

  setReadOnly(readOnly: boolean): void {
    if (!editor) return
    editor.dispatch({
      effects: readOnlyCompartment.reconfigure(EditorState.readOnly.of(readOnly)),
    })
  },
}

document.addEventListener("DOMContentLoaded", createEditor)
