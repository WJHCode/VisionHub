# VisionHub Architecture

VisionHub is a tvOS-first Apple platform media player. The codebase starts with a shared `VisionHubCore` Swift package and thin app targets for tvOS, iOS, and macOS.

## Layers

- `Domain`: stable value types and enums for media, metadata, and credentials.
- `Persistence`: SwiftData models, CloudKit-ready container creation, current user state, and playback progress storage.
- `MediaSources`: provider protocols plus the first WebDAV implementation and an SMB placeholder.
- `Metadata`: provider protocols, TMDB search, and local SwiftData cache storage.
- `Playback`: AVPlayer-backed playback engine and progress save throttling.
- `Features`: shared SwiftUI flows for profile selection, library, detail, and playback.
- `PlatformUI`: small platform-specific modifiers for focus and context menus.

## MVP Decisions

- AVPlayer is the only first engine.
- WebDAV is the first concrete LAN source; SMB remains behind the same provider interface.
- Passwords and tokens belong in Keychain through `CredentialStore`; SwiftData stores only `credentialId`.
- SwiftData models are created with default values where practical so CloudKit schema creation has a clean path.
- All user-specific reads use `userId + mediaId` stable keys.

## App Projects

`VisionHub.xcodeproj` is the active hand-maintained tvOS project and consumes `VisionHubCore` as a local Swift package. The iOS and macOS entry points are prepared under `Apps/`, but their native Xcode targets have not been added yet.

`project.yml` remains as a reference for the intended three-target topology. Do not regenerate over the hand-maintained project without first reconciling target and signing settings.

The shared package can be built and tested immediately with SwiftPM:

```sh
swift test
```

## Completion Tracking

`docs/harness-requirements.md` is the authoritative implementation-status document. Every functional, project configuration, or test change must update its module completion percentage, implemented capabilities, remaining gaps, and verification record in the same change.
