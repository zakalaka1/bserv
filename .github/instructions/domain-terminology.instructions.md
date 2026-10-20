---
description: Workspace-level instructions to be loaded when working in bserv project subdirectories
# applyTo: 'Flutter widget code and all other flutter code base elements
applyTo: 'lib/**/*.dart'
---
- Product name: Book Service
- Short project identifier: bserv
- Users: general public wishing to book an appointment with a service provider; user, logged in user, logged in admin user
- Core concepts: service area, review, booking details, street address, block-off time, week, hours, dates, announcement,
booking, calendar date picker, time, address, city, phone, email, postal code, appointment
- Use consistent domain terminology for Book Service. Maintain a glossary for concepts such as user, admin user, appointment, service area, availability, notification and complete request.
- Do not use multiple English terms for the same concept unless they represent genuinely different business concepts.
- Use domain-relevant names for widgets, classes, methods, routes, models, and user-facing text. Prefer names such as BookingDetailsScreen, BlockoffTimeScreen, ReviewBookingsScreen, AnnouncementsScreen, ServiceAreaScreen, AdminLoginScreen, LoginScreen, BookScreen, TimePickerAndAddressScreen over generic starter names. Keep bserv where it is required by package, directory, application ID, or tooling conventions.