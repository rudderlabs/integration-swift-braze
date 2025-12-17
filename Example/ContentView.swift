//
//  ContentView.swift
//  BrazeExample
//
//  Created by Vishal Gupta on 21/11/25.
//

import SwiftUI
import RudderStackAnalytics

struct ContentView: View {
    private var analyticsManager = AnalyticsManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // User Identity Section
                    VStack(spacing: 12) {
                        Text("User Identity")
                            .font(.headline)

                        Button("Identify User") {
                            analyticsManager.identifyUser()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                    // Install Attribution Events
                    installAttributionEventsSection

                    // Order Completed Events
                    orderCompletedEventsSection

                    // Custom Track Events
                    customTrackEventsSection

                    // Flush Section
                    flushSection
                }
                .padding()
            }
            .navigationTitle("Braze Example")
        }
    }
}

extension ContentView {

    var installAttributionEventsSection: some View {
        VStack(spacing: 12) {
            Text("Install Attribution Events")
                .font(.headline)

            Button("Install Attributed (No Campaign)") {
                analyticsManager.installAttributedWithoutCampaign()
            }
            .buttonStyle(SecondaryButtonStyle())

            Button("Install Attributed (With Campaign)") {
                analyticsManager.installAttributedWithCampaign()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }

    var orderCompletedEventsSection: some View {
        VStack(spacing: 12) {
            Text("Order Completed Events")
                .font(.headline)

            Button("Order Completed (No Products)") {
                analyticsManager.orderCompletedWithoutProducts()
            }
            .buttonStyle(SecondaryButtonStyle())

            Button("Order Completed (Empty Products)") {
                analyticsManager.orderCompletedWithEmptyProducts()
            }
            .buttonStyle(SecondaryButtonStyle())

            Button("Order Completed (Single Product)") {
                analyticsManager.orderCompletedWithSingleProduct()
            }
            .buttonStyle(SecondaryButtonStyle())

            Button("Order Completed (Multiple Products)") {
                analyticsManager.orderCompletedWithMultipleProducts()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }

    var customTrackEventsSection: some View {
        VStack(spacing: 12) {
            Text("Custom Track Events")
                .font(.headline)

            Button("Custom Track (With Properties)") {
                analyticsManager.customTrackEventWithProperties()
            }
            .buttonStyle(SecondaryButtonStyle())

            Button("Custom Track (No Properties)") {
                analyticsManager.customTrackEventWithoutProperties()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }

    var flushSection: some View {
        VStack(spacing: 12) {
            Text("Queue Management")
                .font(.headline)

            Button("Flush") {
                analyticsManager.flush()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(10)
    }

}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    ContentView()
}
