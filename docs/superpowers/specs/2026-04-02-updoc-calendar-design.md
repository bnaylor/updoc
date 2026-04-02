# Design Doc: updoc Calendar Integration

**Date:** 2026-04-02  
**Status:** Draft  
**Topic:** Google Calendar API Sync & Smart Templates

## Overview
This document outlines the implementation plan for the **Calendar Integration** in **updoc**. It covers fetching meeting data directly from the Google Calendar API, displaying it in a collapsible sidebar, and using "Smart Rules" to automatically pre-fill notes with templates and link to existing Google Docs.

## Goals
- **Direct GCalendar Sync:** Use existing OAuth2 credentials to fetch today's events.
- **Frictionless Note Starting:** One-click "Start Note" for upcoming meetings.
- **Smart Template Engine:** Auto-selection of templates based on meeting metadata (title, participants).
- **Auto-Linkage:** Detecting and connecting to "Meeting Notes" URLs in calendar invites.
- **Template Customization:** A rule manager for user-defined template selection logic.

## Architecture

### GCalendarService (Swift Actor)
- **Data Fetching:** Calls the Google Calendar REST API for today's events.
- **Metadata Parsing:** Extracts title, participants, description, and location (for Doc URLs).
- **Polling Logic:** Periodically refreshes the event list (e.g., every 5 minutes).

### Smart Template Engine
- **Rule Evaluator:** A logic engine that matches meeting metadata against a list of `TemplateRule` models.
- **Rule Storage:** User-defined rules are stored in `SwiftData`.
- **Note Pre-filler:** Merges meeting data (date, participants) into the selected Markdown template.

## Key Workflows

### 1. Sidebar Meeting Browser
- A "📅 TODAY'S MEETINGS" section in the sidebar.
- Meetings are listed chronologically.
- "Start Note" button triggers the template engine.

### 2. Auto-Link & Merge
- If a Google Doc URL is detected in the invite, updoc:
    1.  Links the new note to that `googleDocId`.
    2.  Pulls the existing Doc content into the local editor.
- If the Doc is empty, an "Apply My Template" button appears in the header.

### 3. Template Rule Customization
- Settings view to Add/Edit/Delete rules.
- Rule structure: `IF [Attribute] [Operator] [Value] THEN [Apply Template]`.
- Example: `IF Title Contains "1:1" THEN Apply "Standard 1:1"`.

## UI Components
- **SidebarSection:** Displays the list of meeting cards.
- **RuleManagerView:** SwiftUI view for managing template rules.
- **HeaderActions:** Dynamic buttons in the editor for linked Docs and template application.

## Future Considerations
- **EventKit Fallback:** Potentially support native macOS calendars for non-Google users.
- **Recurring Meeting History:** Automatically linking to the note from the *previous* meeting in a series.
- **Conflict Resolution for Rules:** Handling scenarios where multiple rules match a single meeting.
