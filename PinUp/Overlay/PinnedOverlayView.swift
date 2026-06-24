import SwiftUI

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var image: CGImage?
    @Published var titleText = "Pinned Preview"
    @Published var statusText = "Waiting for frames…"
    @Published var showsProgress = true
}

struct PinnedOverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)

            if let image = viewModel.image {
                GeometryReader { geometry in
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color.black)
                }
            } else {
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
        .frame(minWidth: 320, minHeight: 200)
    }
}
