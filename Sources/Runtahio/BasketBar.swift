import SwiftUI
import RuntahioCore

/// The collapsible Runtah Basket pinned to the bottom of the detail area.
struct BasketBar: View {
    @Environment(AppState.self) private var appState
    @Environment(RuntahBasket.self) private var basket

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            header
            if appState.basketExpanded && !basket.isEmpty {
                Divider()
                itemList
            }
        }
        .background(.bar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                appState.basketExpanded.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: appState.basketExpanded ? "chevron.down" : "chevron.up")
                    Image(systemName: "trash.circle.fill").foregroundStyle(.tint)
                    Text(appState.mc.basketName).fontWeight(.medium)
                }
            }
            .buttonStyle(.plain)
            .disabled(basket.isEmpty)

            Text(summaryText)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button(appState.strings.clear) { basket.clear() }
                .disabled(basket.isEmpty)

            Button {
                appState.requestTrash()
            } label: {
                Label(appState.strings.moveToTrash, systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(basket.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(basket.items) { item in
                    HStack(spacing: 8) {
                        Image(
                            systemName: item.type == .directory || item.type == .package
                                ? "folder" : "doc"
                        )
                        .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name).lineLimit(1)
                            Text(item.url.path(percentEncoded: false))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Text(
                            ByteSizeFormatter.string(
                                item.effectiveSize(useAllocated: basket.useAllocatedForReclaimable))
                        )
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        Button {
                            basket.remove(id: item.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 170)
    }

    private var summaryText: String {
        guard !basket.isEmpty else { return appState.strings.basketEmptyHint }
        let itemWord = basket.count == 1 ? "item" : "items"
        return
            "\(basket.count) \(itemWord) · \(ByteSizeFormatter.string(basket.totalReclaimable)) \(appState.strings.reclaimable)"
    }
}
