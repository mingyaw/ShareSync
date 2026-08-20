import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ShareSync")
                        .font(.largeTitle)
                        .fontWeight(.semibold)

                    Text("M0 scaffold: iPhone gateway app shell is ready.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    StatusRow(title: "Pairing", value: "Waiting for Android QR")
                    StatusRow(title: "Manifest", value: "Core decoder tested")
                    StatusRow(title: "Photos", value: "Importer interface ready")
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Receive")
        }
    }
}

private struct StatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
        }
    }
}

#Preview {
    ContentView()
}

