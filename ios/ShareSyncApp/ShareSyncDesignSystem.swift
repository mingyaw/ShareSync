import SwiftUI
import UIKit

enum ShareSyncTone {
    case primary
    case success
    case warning
    case error
    case info
    case neutral

    var color: Color {
        switch self {
        case .primary:
            return ShareSyncTheme.primary
        case .success:
            return ShareSyncTheme.success
        case .warning:
            return ShareSyncTheme.warning
        case .error:
            return ShareSyncTheme.error
        case .info:
            return ShareSyncTheme.info
        case .neutral:
            return .secondary
        }
    }

    var softBackground: Color {
        color.opacity(0.12)
    }

    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        case .info, .primary, .neutral:
            return "info.circle.fill"
        }
    }
}

enum ShareSyncTheme {
    static let primary = adaptive(light: 0x087F70, dark: 0x69D4BC)
    static let success = adaptive(light: 0x16803A, dark: 0x4ADE80)
    static let warning = adaptive(light: 0xB45309, dark: 0xFBBF24)
    static let error = adaptive(light: 0xB42318, dark: 0xFFB4AB)
    static let info = adaptive(light: 0x0E7490, dark: 0x67E8F9)
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let divider = Color.secondary.opacity(0.18)

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(
            UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

private extension UIColor {
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct FeedbackMessage: View {
    let message: String
    let tone: ShareSyncTone

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tone.iconName)
                .foregroundStyle(tone.color)
            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tone.softBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tone.color.opacity(0.24), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct StatusRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .fontWeight(.medium)
                Spacer(minLength: 8)
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ShareSyncTheme.divider)
                .frame(height: 1)
        }
    }
}

struct ProductPanel<Content: View>: View {
    let title: LocalizedStringKey?
    let content: Content

    init(title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ShareSyncTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ShareSyncTheme.divider, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MetricView: View {
    let title: LocalizedStringKey
    let value: String
    let tone: ShareSyncTone

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(tone.color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(tone.softBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tone.color.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct SyncHistoryRow: View {
    let item: SyncHistorySummary

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: item.needsRetry ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(item.needsRetry ? ShareSyncTheme.warning : ShareSyncTheme.success)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.recordedAt, format: .dateTime.month().day().hour().minute())
                    .fontWeight(.semibold)
                Text(
                    String(
                        format: NSLocalizedString("ios.activity.history_format", comment: ""),
                        "\(item.successfulCount)",
                        "\(item.failedCount)"
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(LocalizedStringKey(item.needsRetry ? "ios.activity.status_attention" : "ios.activity.status_complete"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(item.needsRetry ? ShareSyncTheme.warning : ShareSyncTheme.success)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}
