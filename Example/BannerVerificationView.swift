import SwiftUI
import BrazeKit

struct BannerVerificationView: View {
    let braze: Braze
    @State private var placementId = ""
    @State private var activePlacement: String?
    @State private var banner: Braze.Banner?
    @State private var isLoading = false
    @State private var status = "Use a placement targeted only to your test user."

    var body: some View {
        VStack(spacing: 12) {
            Text("Banner dismissal").font(.headline)
            TextField("Test placement ID", text: $placementId)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disabled(isLoading)
            Button("Load Banner") {
                let placement = placementId.trimmingCharacters(in: .whitespacesAndNewlines)
                activePlacement = placement
                banner = nil
                isLoading = true
                status = "Loading Banner..."
                braze.banners.requestBannersRefresh(placementIds: [placement]) { result in
                    DispatchQueue.main.async {
                        isLoading = false
                        switch result {
                        case .success(let banners):
                            banner = banners[placement]
                            status = banner == nil ? "No eligible Banner." : "Banner loaded."
                        case .failure(let error):
                            status = "Refresh failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
            .disabled(isLoading || placementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let placement = activePlacement, banner != nil {
                bannerView(placement: placement)
                    .id(placement)
                    .frame(height: 180)
            }
            Button("Dismiss Banner") {
                guard let banner else { return }
                if let context = banner.context {
                    context.dismiss()
                } else {
                    banner.dismiss(using: braze)
                }
            }
            .disabled(banner == nil)
            Text(status).font(.caption)
        }
        .padding()
    }

    private func bannerView(placement: String) -> VerificationBannerView {
        VerificationBannerView(
            placement: placement,
            braze: braze,
            onRender: { renderedBanner in
                // Use a registered placement's context to receive its onDismiss callback.
                banner = renderedBanner
            },
            onDismiss: { event in
                banner = nil
                status = "Dismissed: \(event.placementId ?? placement), stable key: \(event.stableKey ?? "none")"
            }
        )
    }
}
