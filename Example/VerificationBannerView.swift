import SwiftUI
import BrazeKit
import BrazeUI
import RudderStackAnalytics

struct VerificationBannerView: UIViewRepresentable {
    let placement: String
    let braze: Braze
    let onRender: (Braze.Banner) -> Void
    let onDismiss: (Braze.BannerDismissalEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(placement: placement, onRender: onRender, onDismiss: onDismiss)
    }

    func makeUIView(context: Context) -> BrazeBannerUI.BannerUIView {
        let view = BrazeBannerUI.BannerUIView(placementId: placement, braze: braze)
        view.onDismiss = onDismiss
        braze.banners.registerView(context.coordinator)
        return view
    }

    func updateUIView(_ view: BrazeBannerUI.BannerUIView, context: Context) {
        view.onDismiss = onDismiss
        context.coordinator.didRender = onRender
        context.coordinator.onDismiss = onDismiss
    }

    // A registered placement receives a Banner context with dismissal callbacks.
    // A Banner returned by requestBannersRefresh is not the displayed placement.
    final class Coordinator: NSObject, BrazeBannerPlacement {
        let placementId: String
        var didRender: (Braze.Banner) -> Void
        var onDismiss: ((Braze.BannerDismissalEvent) -> Void)?

        init(placement: String, onRender: @escaping (Braze.Banner) -> Void,
             onDismiss: @escaping (Braze.BannerDismissalEvent) -> Void) {
            placementId = placement
            didRender = onRender
            self.onDismiss = onDismiss
        }

        func render(with banner: Braze.Banner) {
            DispatchQueue.main.async { [weak self] in
                self?.didRender(banner)
            }
        }

        func notifyError(_ error: Error) {
            LoggerAnalytics.debug("Banner verification placement: \(error)")
        }
    }
}
