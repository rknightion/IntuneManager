# Feedback & Contributions

IntuneManager is developed in the open. End users can help shape the roadmap by reporting issues, suggesting enhancements, or sharing successful workflows.

## Report a problem

1. Collect logs via **Settings → Data Management → Export Logs**.
2. Capture the steps you took, the expected result, and what you observed instead.
3. Open an issue on [GitHub](https://github.com/rknightion/IntuneManager/issues) using the bug template.
4. Attach the logs and include the app version (visible in **Settings → About**).

## Request a feature

- Review the [changelog](changelog.md) to make sure the feature is not already planned.
- Open an issue with the `enhancement` label and describe the scenario you are trying to support.
- If the feature requires additional Microsoft Graph permissions, note them so we can document the impact.

## Share improvements

If you are comfortable with Swift and SwiftUI you can contribute directly:

1. Fork the repository and clone it locally.
2. Run `swift package resolve` to align dependencies.
3. Build the app with the `IntuneManager` scheme targeting macOS.
4. Add tests in `IntuneManagerTests` for new logic and run `xcodebuild test -scheme IntuneManager -destination 'platform=macOS,arch=arm64'`.
5. Submit a pull request using the Conventional Commit format (for example `feat(devices): add remote wipe`).

## Provide user feedback

Short on time? Use the in-app **Help → Send Feedback** (coming soon) or email the maintainer. Include screenshots when possible; IntuneManager anonymises personal data before logs are exported.

Thank you for helping make IntuneManager a great companion for Microsoft Intune administrators!
