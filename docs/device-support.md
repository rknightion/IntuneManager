# Device Support

IntuneManager reads managed device data directly from Microsoft Graph. Use this reference to understand which platforms and attributes are surfaced in the UI and what actions are available.

## Supported operating systems

| Platform | Data available | Actions | Notes |
| --- | --- | --- | --- |
| Windows 10/11 | Compliance state, management state, hardware inventory, Azure AD status, Autopilot enrollment, malware counts | Trigger Intune sync | Remote wipe/retire coming soon |
| macOS 12+ | Encryption, supervision, FileVault escrow, hardware specs, battery health, network identifiers | Trigger Intune sync | Shows bootstrap token status when available |
| iOS / iPadOS 15+ | Device ownership, iCloud lock status, Serial/UDID, cellular info, compliance state | Trigger Intune sync | Supervision badge indicates DEP enrollment |
| Android (AOSP & fully managed) | Manufacturer/model, OS version, compliance state, enrollment type | Trigger Intune sync | Work profile data appears when provided by Graph |
| Linux (preview) | Basic hardware and OS metadata | Trigger Intune sync | Limited fields due to Graph support |

Unsupported or legacy platforms appear with minimal metadata and an `Unknown` compliance badge.

## Device detail sections

Each device includes six tabs:

1. **General** – Overview, user relationship, enrolment details, custom notes.
2. **Hardware** – Serial numbers, IMEI/MEID, storage capacity, physical memory, processor architecture.
3. **Management** – Management agent, ownership, join type, autopilot status, management certificate expiry.
4. **Compliance** – Compliance state history, grace period, enforcement status, common policy flags.
5. **Security** – Malware counts, Defender status, jailbreak state, encryption status.
6. **Network** – Ethernet/Wi-Fi MAC addresses, IPv4 address, subnet, cellular carrier.

Use the copy buttons within sections (macOS) or share sheet actions (iOS/iPadOS) to export information for support tickets.

## Filters and search

Open the **Filters** toolbar button to narrow the device list:

- Operating system and OS version
- Ownership (Corporate, Personal, Shared)
- Compliance state (Compliant, Non-compliant, In grace period, Unknown)
- Managed state (Managed, Retire pending, Wipe pending, etc.)
- Encryption, Supervision, Azure AD registration, category, model, manufacturer

Filters stack to produce complex segments. The badge on the filter button indicates how many filters are active. Selecting **Clear Filters** restores the full view.

## Sync behaviour

- **Sync Visible Devices** queues Intune sync requests for every device currently visible (after filters/search).
- **Sync** icons on each row queue a single device sync.
- IntuneManager tracks sync progress per device and re-fetches device metadata once Graph reports completion.
- Permission failures trigger a **Permission Required** alert with the missing Graph scope.

## Device badges

Badges surface device health at a glance:

- **Encrypted** (`lock.shield.fill`) – BitLocker/FileVault or mobile encryption is active.
- **Supervised** (`person.fill.checkmark`) – Device enrolled via ADE/DEP or corporate supervision.
- **Azure AD** (`checkmark.seal.fill`) – Device registered in Azure AD with a trust relationship.
- **Autopilot** (`airplane`) – Windows Autopilot enrolment.

Hover badges on macOS or long-press on iOS for descriptive tooltips.

## Exporting device information

On macOS you can export detailed device information:

1. Open a device.
2. Choose **File → Export Device JSON…** (coming soon) or select specific fields and use `⌘C` to copy.
3. Share the data with support or attach to compliance reviews.

Bulk export is planned; follow the [changelog](changelog.md) for updates.
