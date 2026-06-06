# Repository Guidelines

## Project Structure & Module Organization

`McSrvrS.xcodeproj` contains a single SwiftUI app target, `McSrvrS`, for iOS and macOS. App source lives in `McSrvrS/`. Core entry and shared state are in `McSrvrSApp.swift`, `ContentView.swift`, `AppModelContainer.swift`, and `ServerListModel.swift`. Server pinging code is isolated in `McSrvrS/ServerPinger/`, while detail-screen components live in `McSrvrS/ServerDetail/`. Static images, colors, and app icon assets are under `McSrvrS/Assets.xcassets` and `McSrvrS/McSrvrS.icon/`. Localized strings are in `McSrvrS/Localizable.xcstrings`.

## Build, Test, and Development Commands

Use Xcode 26 or newer, matching the project’s current deployment settings.

- `open McSrvrS.xcodeproj`: open the project for local development.
- `xcodebuild -project McSrvrS.xcodeproj -scheme McSrvrS -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build`: build the iOS simulator app, matching CI.
- `xcodebuild -project McSrvrS.xcodeproj -scheme McSrvrS -destination 'platform=macOS' build`: build the macOS app.
- `xcodebuild -project McSrvrS.xcodeproj -scheme McSrvrS -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' test`: run tests once a test target is added.

## Coding Style & Naming Conventions

Follow the existing Swift style: 4-space indentation, `PascalCase` for types, `camelCase` for properties/functions, and file names that match their primary view or model type. Keep platform-specific behavior behind `#if os(iOS)` or `#if os(macOS)`. Prefer small SwiftUI subviews and extensions over large view bodies. Use Xcode’s formatter before committing; no separate formatter configuration is currently checked in.

## Testing Guidelines

There is no dedicated test target at present. For new logic, add focused XCTest coverage in a future `McSrvrSTests` target, especially for `ServerPinger`, server status parsing, refresh scheduling, and SwiftData model behavior. Name tests after expected behavior, such as `testParsesOnlineServerStatus()`. Always run the relevant `xcodebuild ... test` command before opening a PR.

## Commit & Pull Request Guidelines

Git history uses short, imperative summaries such as `Add macOS menu bar server list` and `Improve localization and add background refresh on macOS`; keep new commits concise and behavior-focused. Pull requests should include a brief description, affected platforms, verification commands, and screenshots or screen recordings for UI changes. Link related issues when available and call out any migration, localization, or background-task changes.

## Security & Configuration Tips

Do not commit user-specific Xcode settings, signing identities, derived data, or secrets. Keep bundle identifiers, background task identifiers, and entitlement-related changes explicit in the PR description because they affect deployment behavior.
