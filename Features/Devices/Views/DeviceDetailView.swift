import SwiftUI

struct DeviceDetailView: View {
    let device: Device
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Device Info Section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Device Information", systemImage: "info.circle")
                        .font(.headline)
                    
                    InfoRow(label: "Name", value: device.deviceName)
                    InfoRow(label: "Model", value: device.model ?? "Unknown")
                    InfoRow(label: "OS", value: "\(device.operatingSystem) \(device.osVersion ?? "")")
                    InfoRow(label: "Serial", value: device.serialNumber ?? "Unknown")
                    InfoRow(label: "Compliance", value: device.complianceState.displayName)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle(device.deviceName)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}