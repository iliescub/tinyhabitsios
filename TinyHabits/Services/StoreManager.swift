import Foundation
import StoreKit
//import SwiftUI
import Combine

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published var isProUnlocked: Bool = false
    @Published var products: [Product] = []

    private let entitlementID = "tinyhabits.pro"

    private init() {
        Task {
            await refresh()
        }
    }

    func refresh() async {
        do {
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result,
                   transaction.productID == entitlementID {
                    isProUnlocked = true
                    return
                }
            }
            isProUnlocked = false

            let storeProducts = try await Product.products(for: [entitlementID])
            products = storeProducts
        } catch {
            print("StoreManager refresh error: \(error)")
        }
    }

    func purchasePro() async {
        guard let product = products.first(where: { $0.id == entitlementID }) else { return }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    isProUnlocked = true
                    await transaction.finish()
                }
            default:
                break
            }
        } catch {
            print("Purchase error: \(error)")
        }
    }
}

