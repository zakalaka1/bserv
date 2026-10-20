---
description: Workspace-level instructions to be loaded when working in bserv project subdirectories
# applyTo: 'Flutter widget code and all other flutter code base elements
applyTo: 'lib/**/*.dart'
---
- I am learning Dart and Flutter. During the learning phase, add concise educational comments for important screen elements, unfamiliar Flutter properties, callbacks, layout widgets, and non-obvious parameters. Explain in the code comments what each element does and why it is used.
- Comments may identify visible controls and structure, such as app bars, menu buttons, search fields, action buttons, containers, rows, columns, and navigation areas. For unfamiliar properties such as automaticallyImplyLeading, explain their practical effect in one brief comment.
- Explain layout relationships, such as why Expanded, Center, Align, Padding, SafeArea, Row, Column, SizedBox, or ConstrainedBox is used. Explain callbacks and state changes when they are introduced.
- Prefer one useful comment for a small related block rather than a comment on every individual line.
- Do not add comments that merely repeat an obvious class or method name. Keep comments concise.
- Use TODO comments for unfinished behavior, with a specific description of the future work.
- For complex screens, navigation flows, stateful widgets, or non-obvious architecture, add an ASCII diagram comment before the relevant class when it can explain the structure in 20 lines or fewer. Keep diagrams simple, accurate, and updated when the structure changes. Do not add diagrams to trivial classes.
- Use Flutter/Dart conventions.
- Preserve compatibility across Android, iOS, and Flutter Web.
- Avoid platform-specific APIs unless necessary.
- When platform-specific code is needed, isolate it and explain the difference.