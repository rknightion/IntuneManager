---
layout: default
title: Home
description: Native macOS companion app for Microsoft Intune administrators to triage devices, push apps, and review reports without opening a browser.
---

# IntuneManager

IntuneManager gives Microsoft Intune administrators a fast, native macOS client. Sign in with Azure AD, browse managed devices, push applications, review configuration profiles, and keep compliance on track without opening a browser.

<div class="hero">
  <p>Stay on top of Microsoft Intune from your Mac with a keyboard-friendly experience that mirrors the Graph API in a user-focused way.</p>
  <div class="hero-badges">
    <a href="getting-started" class="md-button md-button--primary md-button--stretch">🚀 Getting Started Guide</a>
    <a href="supported-entities" class="md-button md-button--stretch">📚 Feature Overview</a>
  </div>
</div>

## Why use IntuneManager?

- **Unified dashboard:** A single view of enrolment, compliance, application health, and assignment coverage with keyboard-accessible charts and filters.
- **Fast device triage:** Filter by OS, ownership, compliance, encryption, and supervision to locate the device you need in seconds, then trigger a sync or drill into details.
- **Bulk application assignments:** Select multiple apps, choose target groups, preview existing assignments, and post Graph API requests in one flow.
- **Configuration profile insight:** Browse catalog, templates, and assignments with split-view navigation optimised for macOS.
- **Actionable reporting:** Review deployment stats, top deployed apps, and recent Intune audit logs with live filters.

## Supported Platforms

IntuneManager is built with SwiftUI and ships as a macOS app.

| Platform | Availability | Highlights |
| --- | --- | --- |
| macOS 15 Sonoma or newer | Native macOS app | Multi-window support, keyboard shortcuts, menu bar commands |

> **Note**: Device and application data is sourced from Microsoft Graph. Make sure the signed-in account has appropriate Intune permissions.

## Quick Start

1. **Register** an app in Azure AD with the required Graph API delegated permissions.
2. **Launch** IntuneManager and complete the built-in setup wizard with your Client ID, Tenant ID, and redirect URI.
3. **Sign in** using Microsoft sign-in. IntuneManager caches tokens securely with MSAL.
4. **Explore** the dashboard, Devices list, and Configuration profiles to confirm data is flowing.

Need more detail? Head to the [Getting Started](getting-started.md) guide for a full walkthrough or review the [FAQ](faq.md) for common scenarios.

---

Looking for release history or roadmap? Check the [Changelog](changelog.md).
