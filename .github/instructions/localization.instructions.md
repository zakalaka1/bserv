---
description: Workspace-level instructions to be loaded when working in bserv project subdirectories
# applyTo: 'Flutter widget code and all other flutter code base elements
applyTo: 'lib/**/*.dart'
---
- Keep all user-facing text localization-ready from the beginning. Do not hard-code visible strings in widgets or application logic; use the project’s i18n/l10n system for labels, buttons, dialogs, errors, validation messages, tooltips, notifications, and accessibility text.
- Support translation differences in length, word order, pluralization, dates, numbers, currency, units, and RTL layouts. Ensure layouts tolerate text wrapping and text scaling. Keep Dart code identifiers stable and descriptive; localize displayed text, not class, widget, method, route, or model names.