# TODOs

## Address Book
- [x] Implement manual "Add New Contact..." dialog.
- [x] Update `GCalendarService` to fetch `displayName` for attendees to store actual full names.
- [/] Investigate role accounts and filter them if they have no names populated (investigated, filtered conference rooms by email).

# Minor bugs
- H1/H2/H3 look the same.  Also true of 4+5+6
- Bullet indentation does not carry over to Google doc since the editor change
- Link rendering is broken since the editor change (but looks fine when synced to Google doc)
- emojis, @-triggers, pill rendering are all broken with the new editor
- `code` is universally grey-on-white now, regardless of theme

# Enhancements
- Remember what was expanded in the "Meeting Notes" section.  It always starts closed (even when just switching back and forth to the "Weekly Snippets" view.
- Add a (Dayname) to the display of the day meeting note items.  eg, "> Day 30 (Thu)"
- Add a right-click menu item for name chips: Look up in Moma.  Use the moma data to fill in the name properly (for ones that didn't have the right scrape data.)
  - Also lets us add people to the address book by username lookup instead of having to type it in.
  - MCP server
  
