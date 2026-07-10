# VisionHub

VisionHub is a tvOS-first Apple-platform home media player, designed around a shared Swift package and thin iOS, macOS, and tvOS app targets.

## Current Shape

- `VisionHubCore`: shared Swift package with SwiftData models, CloudKit-ready container setup, media source protocols, metadata providers, playback services, Keychain credentials, and shared SwiftUI feature views.
- `VisionHub.xcodeproj`: the active tvOS app project, linked to the local `VisionHubCore` package.
- `Apps/`: prepared thin platform entry points for future iOS and macOS targets.
- `project.yml`: retained as an architecture reference; the hand-maintained Xcode project is now authoritative.
- `docs/architecture.md`: implementation architecture and extension points.

## Verify

```sh
swift test
```

## Open the tvOS App

Open the checked-in project directly:

```sh
open VisionHub.xcodeproj
```

The tvOS platform runtime must be installed from Xcode Settings before the app target can build or run.
