import SwiftUI

struct DeviceDetailView: View {
    let device: Device
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with compliance status
                DeviceHeaderView(device: device)

                // Tab picker for different sections
                Picker("Section", selection: $selectedTab) {
                    Text("General").tag(0)
                    Text("Hardware").tag(1)
                    Text("Management").tag(2)
                    Text("Compliance").tag(3)
                    Text("Security").tag(4)
                    Text("Network").tag(5)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case 0:
                        GeneralInfoSection(device: device)
                    case 1:
                        HardwareInfoSection(device: device)
                    case 2:
                        ManagementInfoSection(device: device)
                    case 3:
                        ComplianceInfoSection(device: device)
                    case 4:
                        SecurityInfoSection(device: device)
                    case 5:
                        NetworkInfoSection(device: device)
                    default:
                        GeneralInfoSection(device: device)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(device.deviceName)
        #if os(macOS)
        .navigationSubtitle(device.operatingSystem)
        #endif
    }
}

struct DeviceHeaderView: View {
    let device: Device

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: deviceIcon)
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading) {
                    Text(device.deviceName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(device.userDisplayName ?? "Unknown User")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Compliance badge
                Text(device.complianceState.displayName)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.systemColor(named: device.complianceState.displayColor).opacity(0.2))
                    .cornerRadius(8)
            }

            // Quick status badges
            HStack(spacing: 12) {
                if device.isEncrypted {
                    StatusBadge(icon: "lock.shield.fill", text: "Encrypted", color: .green)
                }
                if device.isSupervised {
                    StatusBadge(icon: "person.fill.checkmark", text: "Supervised", color: .blue)
                }
                if device.azureADRegistered {
                    StatusBadge(icon: "checkmark.seal.fill", text: "Azure AD", color: .purple)
                }
                if device.autopilotEnrolled == true {
                    StatusBadge(icon: "airplane", text: "Autopilot", color: .orange)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var deviceIcon: String {
        switch device.operatingSystem.lowercased() {
        case let os where os.contains("ios") || os.contains("iphone"):
            return "iphone"
        case let os where os.contains("ipad"):
            return "ipad"
        case let os where os.contains("mac"):
            return "laptopcomputer"
        case let os where os.contains("windows"):
            return "pc"
        case let os where os.contains("android"):
            return "smartphone"
        default:
            return "desktopcomputer"
        }
    }
}

struct StatusBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(6)
    }
}

struct GeneralInfoSection: View {
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DeviceSectionHeader(title: "General Information", icon: "info.circle")

            InfoGroup {
                InfoRow(label: "Device Name", value: device.deviceName)
                InfoRow(label: "Model", value: device.model ?? "Unknown")
                InfoRow(label: "Manufacturer", value: device.manufacturer ?? "Unknown")
                InfoRow(label: "Operating System", value: device.operatingSystem)
                InfoRow(label: "OS Version", value: device.osVersion ?? "Unknown")
                InfoRow(label: "Device Type", value: device.deviceType ?? device.chassisType ?? "Unknown")
            }

            DeviceSectionHeader(title: "User Information", icon: "person.circle")

            InfoGroup {
                InfoRow(label: "User Name", value: device.userDisplayName ?? "Unknown")
                InfoRow(label: "User Principal", value: device.userPrincipalName ?? "Unknown")
                InfoRow(label: "User ID", value: device.userId ?? "Unknown")
                InfoRow(label: "Email", value: device.emailAddress ?? "Not available")
                InfoRow(label: "Phone", value: device.phoneNumber ?? "Not available")
            }

            DeviceSectionHeader(title: "Enrollment Details", icon: "checkmark.shield")

            InfoGroup {
                InfoRow(label: "Enrolled Date", value: formatDate(device.enrolledDateTime))
                InfoRow(label: "Last Sync", value: formatDate(device.lastSyncDateTime))
                InfoRow(label: "Enrollment Type", value: device.deviceEnrollmentType ?? device.enrollmentType ?? "Unknown")
                InfoRow(label: "Ownership", value: device.ownership.displayName)
                InfoRow(label: "Device Category", value: device.deviceCategory ?? "None")
            }

            if let notes = device.notes, !notes.isEmpty {
                DeviceSectionHeader(title: "Notes", icon: "note.text")
                Text(notes)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
            }
        }
    }
}

struct HardwareInfoSection: View {
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DeviceSectionHeader(title: "Device Identifiers", icon: "number")

            InfoGroup {
                InfoRow(label: "Serial Number", value: device.serialNumber ?? "Unknown")
                InfoRow(label: "IMEI", value: device.imei ?? "N/A")
                InfoRow(label: "MEID", value: device.meid ?? "N/A")
                InfoRow(label: "UDID", value: device.udid ?? "N/A")
                InfoRow(label: "ICCID", value: device.iccid ?? "N/A")
                InfoRow(label: "Azure AD Device ID", value: device.azureADDeviceId ?? "N/A")
            }

            DeviceSectionHeader(title: "Storage", icon: "internaldrive")

            InfoGroup {
                if let totalStorage = device.totalStorageSpace {
                    InfoRow(label: "Total Storage", value: formatBytes(totalStorage))
                }
                if let freeStorage = device.freeStorageSpace {
                    InfoRow(label: "Free Storage", value: formatBytes(freeStorage))
                }
                if let totalStorage = device.totalStorageSpace,
                   let freeStorage = device.freeStorageSpace {
                    let usedStorage = totalStorage - freeStorage
                    InfoRow(label: "Used Storage", value: formatBytes(usedStorage))
                    let percentage = Double(usedStorage) / Double(totalStorage) * 100
                    InfoRow(label: "Usage", value: String(format: "%.1f%%", percentage))
                }
            }

            DeviceSectionHeader(title: "Hardware Details", icon: "cpu")

            InfoGroup {
                if let memory = device.physicalMemoryInBytes {
                    InfoRow(label: "Memory", value: formatBytes(memory))
                }
                InfoRow(label: "Processor", value: device.processorArchitecture ?? "Unknown")
                InfoRow(label: "SKU Family", value: device.skuFamily ?? "N/A")
                if let skuNumber = device.skuNumber {
                    InfoRow(label: "SKU Number", value: String(skuNumber))
                }
            }

            if device.batteryHealthPercentage != nil || device.batteryChargeCycles != nil || device.batteryLevelPercentage != nil {
                DeviceSectionHeader(title: "Battery Information", icon: "battery.100")

                InfoGroup {
                    if let health = device.batteryHealthPercentage {
                        InfoRow(label: "Battery Health", value: "\(health)%")
                    }
                    if let cycles = device.batteryChargeCycles {
                        InfoRow(label: "Charge Cycles", value: String(cycles))
                    }
                    if let level = device.batteryLevelPercentage {
                        InfoRow(label: "Current Level", value: String(format: "%.1f%%", level))
                    }
                }
            }
        }
    }
}

struct ManagementInfoSection: View {
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DeviceSectionHeader(title: "Management Status", icon: "gear.badge.checkmark")

            InfoGroup {
                InfoRow(label: "Management State", value: device.managementState.displayName)
                InfoRow(label: "Management Agent", value: device.managementAgent ?? "Unknown")
                InfoRow(label: "Registration State", value: device.deviceRegistrationState ?? "Unknown")
                InfoRow(label: "Managed Device Name", value: device.managedDeviceName ?? device.deviceName)
                InfoRow(label: "Join Type", value: device.joinType ?? "N/A")
            }

            if device.autopilotEnrolled != nil || device.requireUserEnrollmentApproval != nil {
                DeviceSectionHeader(title: "Enrollment Configuration", icon: "airplane")

                InfoGroup {
                    if let autopilot = device.autopilotEnrolled {
                        InfoRow(label: "Autopilot Enrolled", value: autopilot ? "Yes" : "No")
                    }
                    if let requireApproval = device.requireUserEnrollmentApproval {
                        InfoRow(label: "Requires Approval", value: requireApproval ? "Yes" : "No")
                    }
                }
            }

            if device.lostModeState != nil || device.activationLockBypassCode != nil {
                DeviceSectionHeader(title: "Lost Mode", icon: "location.slash")

                InfoGroup {
                    if let lostMode = device.lostModeState {
                        InfoRow(label: "Lost Mode State", value: lostMode)
                    }
                    if let bypassCode = device.activationLockBypassCode {
                        InfoRow(label: "Activation Lock Bypass", value: bypassCode)
                    }
                }
            }

            if device.managementCertificateExpirationDate != nil {
                DeviceSectionHeader(title: "Certificate", icon: "lock.doc")

                InfoGroup {
                    if let certExpiry = device.managementCertificateExpirationDate {
                        InfoRow(label: "Certificate Expires", value: formatDate(certExpiry))
                    }
                }
            }
        }
    }
}

struct ComplianceInfoSection: View {
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DeviceSectionHeader(title: "Compliance Status", icon: "checkmark.shield")

            InfoGroup {
                InfoRow(label: "Compliance State", value: device.complianceState.displayName)
                if let gracePeriod = device.complianceGracePeriodExpirationDateTime {
                    InfoRow(label: "Grace Period Expires", value: formatDate(gracePeriod))
                }
                InfoRow(label: "Jail Broken", value: device.jailBroken ?? "Unknown")
                InfoRow(label: "Threat State", value: device.partnerReportedThreatState ?? "Unknown")
            }

            if device.exchangeAccessState != nil || device.easActivated != nil {
                DeviceSectionHeader(title: "Exchange Access", icon: "envelope.badge.shield.half.filled")

                InfoGroup {
                    if let state = device.exchangeAccessState {
                        InfoRow(label: "Access State", value: state)
                    }
                    if let reason = device.exchangeAccessStateReason {
                        InfoRow(label: "Access Reason", value: reason)
                    }
                    if let lastSync = device.exchangeLastSuccessfulSyncDateTime {
                        InfoRow(label: "Last Exchange Sync", value: formatDate(lastSync))
                    }
                    if let easActive = device.easActivated {
                        InfoRow(label: "EAS Activated", value: easActive ? "Yes" : "No")
                    }
                    if let easDeviceId = device.easDeviceId {
                        InfoRow(label: "EAS Device ID", value: easDeviceId)
                    }
                    if let easDate = device.easActivationDateTime {
                        InfoRow(label: "EAS Activation Date", value: formatDate(easDate))
                    }
                }
            }
        }
    }
}

struct SecurityInfoSection: View {
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DeviceSectionHeader(title: "Security Status", icon: "lock.shield")

            InfoGroup {
                InfoRow(label: "Encrypted", value: device.isEncrypted ? "Yes" : "No")
                InfoRow(label: "Supervised", value: device.isSupervised ? "Yes" : "No")
                InfoRow(label: "Azure AD Registered", value: device.azureADRegistered ? "Yes" : "No")
                if let aadRegistered = device.aadRegistered {
                    InfoRow(label: "AAD Registered", value: aadRegistered ? "Yes" : "No")
                }
                if let bootstrapToken = device.bootstrapTokenEscrowed {
                    InfoRow(label: "Bootstrap Token", value: bootstrapToken ? "Escrowed" : "Not Escrowed")
                }
                if let firmwareManaged = device.deviceFirmwareConfigurationInterfaceManaged {
                    InfoRow(label: "Firmware Managed", value: firmwareManaged ? "Yes" : "No")
                }
            }

            if device.androidSecurityPatchLevel != nil || device.securityPatchLevel != nil {
                DeviceSectionHeader(title: "Security Patches", icon: "shield.lefthalf.filled")

                InfoGroup {
                    if let androidPatch = device.androidSecurityPatchLevel {
                        InfoRow(label: "Android Security Patch", value: androidPatch)
                    }
                    if let securityPatch = device.securityPatchLevel {
                        InfoRow(label: "Security Patch Level", value: securityPatch)
                    }
                }
            }

            if device.windowsActiveMalwareCount != nil || device.windowsRemediatedMalwareCount != nil {
                DeviceSectionHeader(title: "Windows Security", icon: "shield.checkerboard")

                InfoGroup {
                    if let activeMalware = device.windowsActiveMalwareCount {
                        InfoRow(label: "Active Malware", value: String(activeMalware))
                    }
                    if let remediatedMalware = device.windowsRemediatedMalwareCount {
                        InfoRow(label: "Remediated Malware", value: String(remediatedMalware))
                    }
                }
            }
        }
    }
}

struct NetworkInfoSection: View {
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DeviceSectionHeader(title: "Network Information", icon: "network")

            InfoGroup {
                InfoRow(label: "WiFi MAC", value: device.wiFiMacAddress ?? "Unknown")
                InfoRow(label: "Ethernet MAC", value: device.ethernetMacAddress ?? "Unknown")
                InfoRow(label: "IP Address", value: device.ipAddressV4 ?? "Unknown")
                InfoRow(label: "Subnet", value: device.subnetAddress ?? "Unknown")
            }

            if device.subscriberCarrier != nil || device.cellularTechnology != nil {
                DeviceSectionHeader(title: "Cellular Information", icon: "antenna.radiowaves.left.and.right")

                InfoGroup {
                    InfoRow(label: "Carrier", value: device.subscriberCarrier ?? "Unknown")
                    InfoRow(label: "Technology", value: device.cellularTechnology ?? "Unknown")
                }
            }

            if let remoteUrl = device.remoteAssistanceSessionUrl, !remoteUrl.isEmpty {
                DeviceSectionHeader(title: "Remote Assistance", icon: "person.fill.questionmark")

                InfoGroup {
                    InfoRow(label: "Session URL", value: remoteUrl)
                }
            }
        }
    }
}

struct DeviceSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
        }
        .padding(.top, 8)
    }
}

struct InfoGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(minWidth: 140, alignment: .leading)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
    }
}

// Helper functions
private func formatDate(_ date: Date?) -> String {
    guard let date = date else { return "Unknown" }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .binary
    return formatter.string(fromByteCount: bytes)
}