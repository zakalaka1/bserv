---
description: Workspace-level instructions to be loaded when working in bserv project subdirectories
# applyTo: 'Bserv project Flutter widget code and all other flutter code base elements
applyTo: 'lib/**/*.dart'
---
- Design for comfortable one-handed use by both right- and left-handed users. Keep primary actions reachable, provide adequate touch targets and spacing, avoid gesture-only or corner-dependent controls, and validate layouts on small phones, large phones, tablets, and browser sizes. Treat RTL language support as a separate localization requirement.
- Implement light and dark themes using Flutter’s theme system. Prefer system theme by default unless product requirements specify otherwise. Use theme-aware colors throughout, maintain accessible contrast, and test important screens in both modes.
- Consider responsive layouts, touch input, browser sizing, keyboard input, and mobile navigation.