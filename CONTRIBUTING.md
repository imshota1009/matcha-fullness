# Contributing to Matcha Fullness

Thank you for your interest! Matcha Fullness started as a two-day hackathon project, and ideas, bug reports and pull requests are all welcome.
（日本語での Issue・プルリクエストも歓迎です。）

## Ways to contribute
- **Report a bug:** open an [Issue](../../issues) with your iPhone model, iOS version, what you did, and what you expected.
- **Suggest an idea:** open an Issue describing the experience you have in mind. Small, calm ideas fit this app best.
- **Send a pull request:** pick an open Issue (or open one first for bigger changes) so we can agree on the direction.

## Development setup
1. Use Xcode 26 or later and an iPhone with iOS 26 or later. Motion, haptics and sound only work on a real device.
2. Copy `Secrets.example.xcconfig` to `Secrets.xcconfig` (it is git-ignored) and fill in any values you need.
3. Open `Shibui/Shibui.xcodeproj`, select your own development team in Signing & Capabilities, and run the `Shibui` scheme.

## Pull request guidelines
- Keep each pull request focused on one change, and describe what you changed and how you tested it on a device.
- Follow the existing code style and the shared components in `DesignSystem/`.
- Keep the app offline-first: records stay on the device, and no new tracking or network calls without discussion.
- Add credits for any new assets, with a license that allows redistribution (see `Shibui/App/Sounds/CREDITS.txt`).

## License
By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
