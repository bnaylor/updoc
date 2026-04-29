# path forward

This has been really instructive and I like the overall shape of what we've built so far.

Things I like the most:
* Low-friction note creation - this was one of the major goals
* Organization is clean and easy
* Google integration with docs and calendar is fantastic
* Templating and themes
* The ability to customize the entire UI to suit my needs

Things that are causing me doubt:
* Customizing the editor

## Why's the editor a problem?
Making the editor as it is now behave the way we want it to for simultaneous 
markdown editing and display is increasingly feeling like a collection of 
edge cases and special overrides that are potentially fighting amongst themselves.

Formatting, intending bullets, drawing custom glyphs, etc.

My gut tells me this is an already-solved problem and it's not trivial to keep
extending and maintaining.  Nor is this a "core competency" or something that
I find interesting to work on in depth.

## Alternatives?
What if we pause on this and think about ways to extract the interesting value
we have put together and use it in a different way?

Two major paths I see:
* Import someone else's editor - vscode or similar might have a reasonable way 
to repackage a hardened, tested editor into our Swift application.  We use the
same skeleton for our app but someone else's editor.
* Export our Google-integration and/or organizational approaches into another
program, such as Noteplan or Obsidian, using their plugin framework.
    * Support this by refactoring unique functionality for the Google ecosystem
      from updoc into a standalone "sync daemon" or something like that which
      the plugins can access on localhost.

Pros:
* Don't write/maintain an editor
* Reuse community learnings from the past n decades about writing editors
Cons:
* Less ability to customize either the editor or the interface

Noteplan plugin development info:
* https://help.noteplan.co/article/67-create-command-bar-plugins
* https://github.com/NotePlan/plugins

Obsidian plugin development info:
* https://docs.obsidian.md/Plugins/Getting+started/Build+a+plugin

The VSCode Monaco editor:
* https://microsoft.github.io/monaco-editor/
* https://github.com/microsoft/monaco-editor


