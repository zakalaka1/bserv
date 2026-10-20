---
description: Workspace-level instructions to be loaded when working in bserv project subdirectories
# applyTo: 'Firebase and Flutter auxillary code and all other flutter code base elements
applyTo: 'lib/services/**/*.dart,lib/data/**/*.dart'
---
- The backend is Firebase on Google Cloud Platform. When backend functionality is requested, recommend the appropriate Firebase service, packages, platform configuration, initialization, environment strategy, and Security Rules before implementation. Ask for approval before adding dependencies or changing Android, iOS, Web, Firebase, or deployment configuration. Never place service-account credentials or private keys in the client or repository.