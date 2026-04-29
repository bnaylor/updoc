import { EditorView, keymap } from "@codemirror/view"
import { EditorState, Compartment } from "@codemirror/state"
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands"
import { markdown, markdownLanguage } from "@codemirror/lang-markdown"
import { GFM } from "@lezer/markdown"
import { syntaxHighlighting, defaultHighlightStyle } from "@codemirror/language"

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

// ─── Editor instance ───────────────────────────────────────────────────────────

let editor: EditorView | null = null

function createEditor(): void {
  editor = new EditorView({
    state: EditorState.create({
      doc: "",
      extensions: [
        history(),
        keymap.of([...defaultKeymap, ...historyKeymap, indentWithTab]),
        markdown({ base: markdownLanguage, extensions: [GFM] }),
        syntaxHighlighting(defaultHighlightStyle),
        EditorView.lineWrapping,
        readOnlyCompartment.of(EditorState.readOnly.of(false)),
        EditorView.updateListener.of((update) => {
          if (update.docChanged) notifyContentChanged(update.view)
        }),
        EditorView.theme({
          "&": {
            height: "100%",
            fontSize: "var(--updoc-font-size, 16px)",
            fontFamily: "var(--updoc-font-family, -apple-system, sans-serif)",
          },
          ".cm-scroller": { overflow: "auto" },
          ".cm-content": { padding: "16px 20px", caretColor: "var(--updoc-text, currentColor)" },
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

  setTheme(vars: Record<string, string>): void {
    const root = document.documentElement
    for (const [key, value] of Object.entries(vars)) {
      root.style.setProperty(key, value)
    }
    if (vars["--updoc-bg"]) document.body.style.backgroundColor = vars["--updoc-bg"]
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
