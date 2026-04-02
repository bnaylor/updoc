# updoc requirements

I would like to create a local macos application that is primarily a markdown-style
editor - mostly for note-taking.

What's updoc?  hah gotcha

## Requirements

We'll optimize for the following traits:

- Frictionless note-taking when hopping from meeting to meeting with little time to prepare between
    - Fast local editing response (no lag)
    - Easy creation of new notes
    - Easy management / organization of notes 
    - Efficient and flexible searching, tagging, filtering
- Integration with key parts of the Google ecoystem
    - Google Docs
        - Seamless import / export between updoc and Google Docs content (mine and other peoples' docs)
    - Moma org chart / teams / person lookup in the directory (similar to how docs lets you @<person> to embed a chip for a contact)
    - MCP server for Gemini access to updoc content, or other ways of exposing content to AI agents
- Support for major note/doc editing features
    - Markdown or doc style formatting (or both modes)
    - Embedded images
        - Insert via menu / selection dialog, cut & paste, drag & drop
    - Tables
    - Hyperlinks
    - Select types of "chips"
        - Contacts
        - Dropdowns
    - Application of document templates to new docs

## Optional / later integrations:
- Google Calendar / Tasks
    - Mirror or integrate between Google and Sharpei?
- Integration with, or subsumption of Sharpei TODO management - https://github.com/bnaylor/sharpei
- Gemini API for things like "help me write" or similar AI-assist features
- Potentially integrate with Apple foundational models as APIs become supported

## Features / Constraints
- Native mac application
    - Ideally Swift, but ObjC/Cocoa if we have to
        - Swift is more modern, seems to be the path forward, and we have some pretty beefy agent skills for that language (with more out there if we need them.)
- Local storage OR offline caching of select content
    - Enable offline editing (travel, dead zones, errands)
    - Reduce impact from slow networks
- Faithful rendering of updoc content into Google Docs format
- Obey Google security standards
    - No non-Google cloud storage or cloud APIs
    - Use all the proper authentication mechanisms
    - Encrypt anything stored locally with compliant technologies and key management
- Customization of colors and things similar to what NotePlan can do - make it a pleasant app to use.

## Inspirations
- I really like portions of the NotePlan experience, particularly note-taking: https://noteplan.co/
- I use gNotebooks today to solve this problem, but there are problems with it that add just enough friction that make me fall off the wagon - https://gnotebooks.googleplex.com/
    - Organization is kind of a pain
    - New note creation is slow
    - gNotebooks wants to re-authorize itself constantly which slows things down further
    - Some common Google Docs features do not work properly in this interface
    - Integration with other tools is out of my control
    - Gemini finds it fairly cumbersome to interact with (via drive files - ugh)
- I have tried a million other apps and I know what I do and don't like.  This is what drives the "optimize for" requirements above.

## Options
- Not opposed to importing an editor SDK from an existing (free, open source) product if that is the best route to producing a rich-enough editor interface.  vscode or other popular, maintained editors..  We should perform a due diligence search for the options and pros/cons here.
- Integration with Google Docs: Please see this separate doc for the rundown from Duckie: `docs_interaction.md`

