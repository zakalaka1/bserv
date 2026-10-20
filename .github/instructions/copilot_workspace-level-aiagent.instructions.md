---
description: Workspace-level instructions to be loaded when working in bserv project subdirectories
applyTo: '**'
---

<!-- Tip: Use /create-instructions in chat to generate content with agent assistance -->

<!-- - I am learning Dart and Flutter. Act as a patient senior pair-programmer. -->
- I am learning Dart and Flutter. During the learning phase, add concise educational comments for important screen elements, unfamiliar Flutter properties, callbacks, layout widgets, and non-obvious parameters. Explain what each element does and why it is used.
- Comments may identify visible controls and structure, such as app bars, menu buttons, search fields, action buttons, containers, rows, columns, and navigation areas. For unfamiliar properties such as automaticallyImplyLeading, explain their practical effect in one brief comment.
- Explain layout relationships, such as why Expanded, Center, Align, Padding, SafeArea, Row, Column, SizedBox, or ConstrainedBox is used. Explain callbacks and state changes when they are introduced.
- Prefer one useful comment for a small related block rather than a comment on every individual line. Do not add comments that merely repeat an obvious class or method name. Keep comments concise.
- Use TODO comments for unfinished behavior, with a specific description of the future work.
- Use Flutter/Dart conventions.
- Preserve compatibility across Android, iOS, and Flutter Web.
- Avoid platform-specific APIs unless necessary.
- When platform-specific code is needed, isolate it and explain the difference.
- Consider responsive layouts, touch input, browser sizing, keyboard input, and mobile navigation.
- Product name: Book Service
- Short project identifier: bserv
- Users: general public wishing to book an appointment with a service provider 
- Core concepts: service area, users, logged in user, admin user, blocked-off time, appointments, contact details, availability, notifications
- Use consistent domain terminology for Book Service. Maintain a glossary for concepts such as user, admin user, appointment, service area, availability, notification and complete request. Do not use multiple English terms for the same concept unless they represent genuinely different business concepts.
- Use domain-relevant names for widgets, classes, methods, routes, models, and user-facing text. Prefer names such as BookingDetailsScreen, BlockoffTimeScreen, ReviewBookingsScreen, AnnouncementsScreen, ServiceAreaScreen, AdminLoginScreen, LoginScreen, BookScreen, TimePickerAndAddressScreen over generic starter names. Keep bserv where it is required by package, directory, application ID, or tooling conventions.
- For complex screens, navigation flows, stateful widgets, or non-obvious architecture, add an ASCII diagram comment before the relevant class when it can explain the structure in 20 lines or fewer. Keep diagrams simple, accurate, and updated when the structure changes. Do not add diagrams to trivial classes.
- The backend is Firebase on Google Cloud Platform. When backend functionality is requested, recommend the appropriate Firebase service, packages, platform configuration, initialization, environment strategy, and Security Rules before implementation. Ask for approval before adding dependencies or changing Android, iOS, Web, Firebase, or deployment configuration. Never place service-account credentials or private keys in the client or repository.
- Prefer camelCase for Firestore document field names so persisted keys match Dart model properties (for example, `createdBy`, `createdAt`, and `quotedPrice`). Do not mix camelCase and snake_case within the same Firestore schema. When renaming persisted fields, update readers, writers, Security Rules, tests, and existing documents or provide an explicit migration path.
- Design for comfortable one-handed use by both right- and left-handed users. Keep primary actions reachable, provide adequate touch targets and spacing, avoid gesture-only or corner-dependent controls, and validate layouts on small phones, large phones, tablets, and browser sizes. Treat RTL language support as a separate localization requirement.
- Implement light and dark themes using Flutter’s theme system. Prefer system theme by default unless product requirements specify otherwise. Use theme-aware colors throughout, maintain accessible contrast, and test important screens in both modes.
- Use a maintainable, feature-oriented Flutter structure. Keep presentation, domain models, data access, shared services, and reusable widgets separated appropriately. Prefer simple patterns first, introduce state management or additional architecture when complexity justifies it, and explain significant structural decisions.
- Do not reorganize the entire project or introduce a state-management framework without first explaining the trade-offs and obtaining approval.
- Keep all user-facing text localization-ready from the beginning. Do not hard-code visible strings in widgets or application logic; use the project’s i18n/l10n system for labels, buttons, dialogs, errors, validation messages, tooltips, notifications, and accessibility text. Support translation differences in length, word order, pluralization, dates, numbers, currency, units, and RTL layouts. Ensure layouts tolerate text wrapping and text scaling. Keep Dart code identifiers stable and descriptive; localize displayed text, not class, widget, method, route, or model names.