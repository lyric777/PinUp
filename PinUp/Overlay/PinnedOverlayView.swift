import SwiftUI

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var image: CGImage?
    @Published var titleText = L10n.tr("pinned_preview")
    @Published var statusText = L10n.tr("waiting_for_frames")
    @Published var showsProgress = true
}

struct PinnedOverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel

    var body: some View {
        ZStack {
            if let image = viewModel.image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.black.opacity(0.92)

                VStack(spacing: 14) {
                    Image(systemName: "pin")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(viewModel.titleText)
                        .font(.headline)
                        .foregroundStyle(.white)

                    if viewModel.showsProgress {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }

                    Text(viewModel.statusText)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 260)
                }
                .padding(24)
            }
        }
        .frame(minWidth: 180, minHeight: 160)
    }
}
