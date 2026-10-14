// App Store Connect API for Fledge's listing (MKT-6, REL-2). Never prints the key or the token.
//
// Usage (run through scripts/watchdog.sh):
//   swift scripts/asc.swift status                 read-only: app, versions, current subtitle/keywords, screenshot sets
//   swift scripts/asc.swift metadata [file.json]   subtitle (app info) + description, keywords, promotional text (version)
//   swift scripts/asc.swift screenshots            replaces the iPhone 6.9" and iPad 13" sets with Design/AppStore/*.png
//   swift scripts/asc.swift iap                    creates Fledge Pro (subscription group, yearly + monthly, lifetime): names,
//                                                  prices (all territories, equalized from USA), 7-day free trial, availability
//   swift scripts/asc.swift review-status          read-only: category, age rating, content rights, price, contact, copyright
//   swift scripts/asc.swift review-setup           sets categories, content rights, age rating answers and the free price
//   swift scripts/asc.swift review-contact [file]  App Review contact + copyright from a git-ignored JSON file
//   swift scripts/asc.swift iap-status             read-only: each product's state, localizations, prices, review screenshot, note
//   swift scripts/asc.swift iap-review [png]       App Review screenshot + review note on all three products
//                                                  (png from the UI test testPaywallShowsPlansForAppReview)
//   swift scripts/asc.swift builds                 lists builds and their processing state
//   swift scripts/asc.swift attach-build <number>  attaches a processed build to the editable 1.0 version
//
// Key: ~/APIkeys/appstoreconnect/AuthKey_<KEYID>.p8; issuer ID: the UUID inside "App Store Connect Issuer ID.rtf" next to it.
// Edits go to the iOS version that is still editable (PREPARE_FOR_SUBMISSION and similar); nothing is submitted for review.

import Foundation
import CryptoKit

let bundleID = "com.smartapps.TinyHabits"
let keyDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("APIkeys/appstoreconnect")
let api = URL(string: "https://api.appstoreconnect.apple.com")!

enum ASCError: Error, CustomStringConvertible {
    case setup(String), http(Int, String)
    var description: String {
        switch self {
        case .setup(let message): "setup: \(message)"
        case .http(let code, let body): "HTTP \(code): \(body.prefix(600))"
        }
    }
}

// MARK: - Auth (ES256 JWT, 15 minutes)

func token() throws -> String {
    let files = try FileManager.default.contentsOfDirectory(atPath: keyDir.path)
    guard let p8 = files.first(where: { $0.hasPrefix("AuthKey_") && $0.hasSuffix(".p8") }) else { throw ASCError.setup("no AuthKey_*.p8") }
    let keyID = String(p8.dropFirst("AuthKey_".count).dropLast(".p8".count))
    let pem = try String(contentsOf: keyDir.appendingPathComponent(p8), encoding: .utf8)
    let key = try P256.Signing.PrivateKey(pemRepresentation: pem)
    guard let rtf = files.first(where: { $0.lowercased().contains("issuer") }) else { throw ASCError.setup("no issuer file") }
    let text = try String(contentsOf: keyDir.appendingPathComponent(rtf), encoding: .utf8)
    let pattern = try NSRegularExpression(pattern: "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
    guard let match = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          let range = Range(match.range, in: text) else { throw ASCError.setup("no issuer UUID in the issuer file") }
    let issuer = String(text[range])

    func b64(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    let now = Int(Date().timeIntervalSince1970)
    let header = try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": keyID, "typ": "JWT"])
    let payload = try JSONSerialization.data(withJSONObject: ["iss": issuer, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"])
    let signingInput = b64(header) + "." + b64(payload)
    let signature = try key.signature(for: Data(signingInput.utf8)).rawRepresentation
    return signingInput + "." + b64(signature)
}

// Line-buffered output, so progress shows up through a pipe (the watchdog kills silent runs).
setvbuf(stdout, nil, _IOLBF, 0)

let jwt: String
do { jwt = try token() } catch { print("error: \(error)"); exit(1) }

@discardableResult
func call(_ method: String, _ path: String, _ body: [String: Any]? = nil) async throws -> [String: Any] {
    var request = URLRequest(url: path.hasPrefix("http") ? URL(string: path)! : URL(string: api.absoluteString + path)!)
    request.httpMethod = method
    request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
    if let body {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(code) else { throw ASCError.http(code, String(decoding: data, as: UTF8.self)) }
    if data.isEmpty { return [:] }
    return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
}

func items(_ json: [String: Any]) -> [[String: Any]] { json["data"] as? [[String: Any]] ?? [] }
func attrs(_ item: [String: Any]) -> [String: Any] { item["attributes"] as? [String: Any] ?? [:] }
func id(_ item: [String: Any]) -> String { item["id"] as? String ?? "" }

// MARK: - Lookups

func app() async throws -> [String: Any] {
    let found = items(try await call("GET", "/v1/apps?filter[bundleId]=\(bundleID)"))
    guard let app = found.first else { throw ASCError.setup("no app with bundle ID \(bundleID)") }
    return app
}

let editableStates: Set<String> = ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"]

func editableVersion(appID: String) async throws -> [String: Any] {
    let versions = items(try await call("GET", "/v1/apps/\(appID)/appStoreVersions?filter[platform]=IOS&limit=10"))
    if let editable = versions.first(where: { editableStates.contains(attrs($0)["appStoreState"] as? String ?? attrs($0)["appVersionState"] as? String ?? "") }) {
        return editable
    }
    throw ASCError.setup("no editable iOS version; versions: \(versions.map { "\(attrs($0)["versionString"] ?? "?")=\(attrs($0)["appStoreState"] ?? "?")" })")
}

func versionLocalization(versionID: String, locale: String) async throws -> [String: Any] {
    let localizations = items(try await call("GET", "/v1/appStoreVersions/\(versionID)/appStoreVersionLocalizations"))
    if let existing = localizations.first(where: { attrs($0)["locale"] as? String == locale }) { return existing }
    let created = try await call("POST", "/v1/appStoreVersionLocalizations", ["data": [
        "type": "appStoreVersionLocalizations", "attributes": ["locale": locale],
        "relationships": ["appStoreVersion": ["data": ["type": "appStoreVersions", "id": versionID]]],
    ]])
    return created["data"] as? [String: Any] ?? [:]
}

func editableAppInfo(appID: String) async throws -> [String: Any] {
    let infos = items(try await call("GET", "/v1/apps/\(appID)/appInfos"))
    return infos.first { (attrs($0)["appStoreState"] as? String ?? attrs($0)["state"] as? String ?? "") != "READY_FOR_SALE" } ?? infos.first ?? [:]
}

// MARK: - Commands

func status() async throws {
    let app = try await app()
    print("app: \(attrs(app)["name"] ?? "?") (\(id(app)))")
    for version in items(try await call("GET", "/v1/apps/\(id(app))/appStoreVersions?filter[platform]=IOS&limit=10")) {
        print("version \(attrs(version)["versionString"] ?? "?"): \(attrs(version)["appStoreState"] ?? attrs(version)["appVersionState"] ?? "?")")
        for loc in items(try await call("GET", "/v1/appStoreVersions/\(id(version))/appStoreVersionLocalizations")) {
            let a = attrs(loc)
            print("  \(a["locale"] ?? "?"): keywords=\(a["keywords"] ?? "–"), promo=\((a["promotionalText"] as? String)?.prefix(60) ?? "–"), description=\((a["description"] as? String)?.count ?? 0) chars")
            for set in items(try await call("GET", "/v1/appStoreVersionLocalizations/\(id(loc))/appScreenshotSets")) {
                let shots = items(try await call("GET", "/v1/appScreenshotSets/\(id(set))/appScreenshots"))
                print("    screenshots \(attrs(set)["screenshotDisplayType"] ?? "?"): \(shots.count)")
            }
        }
    }
    let info = try await editableAppInfo(appID: id(app))
    for loc in items(try await call("GET", "/v1/appInfos/\(id(info))/appInfoLocalizations")) {
        print("app info \(attrs(loc)["locale"] ?? "?"): name=\(attrs(loc)["name"] ?? "–"), subtitle=\(attrs(loc)["subtitle"] ?? "–")")
    }
    for submission in (try? await all("/v1/reviewSubmissions?filter[app]=\(id(app))&limit=20")) ?? [] {
        let a = attrs(submission)
        print("review submission: \(a["state"] ?? "?") (\(a["platform"] ?? "?")), submitted \(a["submittedDate"] ?? "–")")
    }
    for group in (try? await all("/v1/apps/\(id(app))/subscriptionGroups")) ?? [] {
        for sub in (try? await all("/v1/subscriptionGroups/\(id(group))/subscriptions")) ?? [] {
            print("subscription \(attrs(sub)["productId"] ?? "?"): \(attrs(sub)["state"] ?? "?")")
        }
    }
    for product in (try? await all("/v1/apps/\(id(app))/inAppPurchasesV2?limit=200")) ?? [] {
        print("in-app purchase \(attrs(product)["productId"] ?? "?"): \(attrs(product)["state"] ?? "?")")
    }
}

func metadata(_ file: String) async throws {
    let meta = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: file))) as? [String: String] ?? [:]
    let locale = meta["locale"] ?? "en-US"
    let app = try await app()

    let info = try await editableAppInfo(appID: id(app))
    if let loc = items(try await call("GET", "/v1/appInfos/\(id(info))/appInfoLocalizations")).first(where: { attrs($0)["locale"] as? String == locale }) {
        var infoFields: [String: String] = [:]
        for key in ["subtitle", "privacyPolicyUrl"] { if let value = meta[key] { infoFields[key] = value } }
        try await call("PATCH", "/v1/appInfoLocalizations/\(id(loc))", ["data": ["type": "appInfoLocalizations", "id": id(loc), "attributes": infoFields]])
        print("app info \(locale): set \(infoFields.keys.sorted().joined(separator: ", "))")
    }

    let version = try await editableVersion(appID: id(app))
    let loc = try await versionLocalization(versionID: id(version), locale: locale)
    var fields: [String: String] = [:]
    for key in ["description", "keywords", "promotionalText", "supportUrl", "marketingUrl"] { if let value = meta[key] { fields[key] = value } }
    try await call("PATCH", "/v1/appStoreVersionLocalizations/\(id(loc))", ["data": ["type": "appStoreVersionLocalizations", "id": id(loc), "attributes": fields]])
    print("version \(attrs(version)["versionString"] ?? "?") \(locale): set \(fields.keys.sorted().joined(separator: ", "))")
}

func upload(set displayType: String, files: [URL], localizationID: String) async throws {
    let sets = items(try await call("GET", "/v1/appStoreVersionLocalizations/\(localizationID)/appScreenshotSets"))
    var setID = sets.first { attrs($0)["screenshotDisplayType"] as? String == displayType }.map(id)
    if setID == nil {
        let created = try await call("POST", "/v1/appScreenshotSets", ["data": [
            "type": "appScreenshotSets", "attributes": ["screenshotDisplayType": displayType],
            "relationships": ["appStoreVersionLocalization": ["data": ["type": "appStoreVersionLocalizations", "id": localizationID]]],
        ]])
        setID = (created["data"] as? [String: Any]).map(id)
    }
    guard let setID else { throw ASCError.setup("couldn't create \(displayType)") }
    for old in items(try await call("GET", "/v1/appScreenshotSets/\(setID)/appScreenshots")) {
        try await call("DELETE", "/v1/appScreenshots/\(id(old))")
    }
    for file in files {
        let data = try Data(contentsOf: file)
        let reserved = try await call("POST", "/v1/appScreenshots", ["data": [
            "type": "appScreenshots", "attributes": ["fileName": file.lastPathComponent, "fileSize": data.count],
            "relationships": ["appScreenshotSet": ["data": ["type": "appScreenshotSets", "id": setID]]],
        ]])
        guard let shot = reserved["data"] as? [String: Any],
              let operations = attrs(shot)["uploadOperations"] as? [[String: Any]] else { throw ASCError.setup("no upload operations") }
        for operation in operations {
            guard let url = (operation["url"] as? String).flatMap(URL.init(string:)),
                  let offset = operation["offset"] as? Int, let length = operation["length"] as? Int else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = operation["method"] as? String ?? "PUT"
            for header in operation["requestHeaders"] as? [[String: String]] ?? [] {
                if let name = header["name"], let value = header["value"] { request.setValue(value, forHTTPHeaderField: name) }
            }
            let (_, response) = try await URLSession.shared.upload(for: request, from: data.subdata(in: offset..<(offset + length)))
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else { throw ASCError.http(code, "upload part of \(file.lastPathComponent)") }
        }
        let checksum = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try await call("PATCH", "/v1/appScreenshots/\(id(shot))", ["data": [
            "type": "appScreenshots", "id": id(shot), "attributes": ["uploaded": true, "sourceFileChecksum": checksum],
        ]])
        print("  \(displayType): uploaded \(file.lastPathComponent)")
    }
}

func screenshots() async throws {
    let app = try await app()
    let version = try await editableVersion(appID: id(app))
    let loc = try await versionLocalization(versionID: id(version), locale: "en-US")
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Design/AppStore")
    func pngs(_ dir: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "png" && $0.lastPathComponent.first?.isNumber == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    // 1320 × 2868 goes in the 6.9"/6.7" iPhone set; 2064 × 2752 in the 13" iPad set.
    try await upload(set: "APP_IPHONE_67", files: try pngs(root), localizationID: id(loc))
    try await upload(set: "APP_IPAD_PRO_3GEN_129", files: try pngs(root.appendingPathComponent("iPad")), localizationID: id(loc))
}

// MARK: - In-app purchases (REL-0)

/// Every page of a list endpoint.
func all(_ path: String) async throws -> [[String: Any]] {
    var result: [[String: Any]] = []
    var next: String? = path
    while let current = next {
        let page = try await call("GET", current)
        result += items(page)
        next = (page["links"] as? [String: Any])?["next"] as? String
    }
    return result
}

func ref(_ type: String, _ id: String) -> [String: Any] { ["data": ["type": type, "id": id]] }

struct PlanSpec {
    let productID: String, reference: String, displayName: String, description: String, price: String
    let period: String?   // subscriptions only: ONE_MONTH, ONE_YEAR
    let level: Int
    let freeTrial: Bool
}

let plans = [
    PlanSpec(productID: "com.smartapps.TinyHabits.pro.yearly", reference: "Pro Yearly", displayName: "Fledge Pro Yearly",
             description: "All three habits from Apple Health, every widget.", price: "19.99", period: "ONE_YEAR", level: 1, freeTrial: true),
    PlanSpec(productID: "com.smartapps.TinyHabits.pro.monthly", reference: "Pro Monthly", displayName: "Fledge Pro Monthly",
             description: "All three habits from Apple Health, every widget.", price: "2.99", period: "ONE_MONTH", level: 2, freeTrial: false),
]
let lifetime = PlanSpec(productID: "com.smartapps.TinyHabits.pro.lifetime", reference: "Pro Lifetime", displayName: "Fledge Pro Lifetime",
                        description: "Fledge Pro forever. One payment.", price: "39.99", period: nil, level: 0, freeTrial: false)

func iap() async throws {
    let appID = id(try await app())
    let territories = try await all("/v1/territories?limit=200").map(id)
    print("territories: \(territories.count)")

    // Subscription group "Fledge Pro".
    var group = try await all("/v1/apps/\(appID)/subscriptionGroups").first { attrs($0)["referenceName"] as? String == "Fledge Pro" }
    if group == nil {
        group = try await call("POST", "/v1/subscriptionGroups", ["data": [
            "type": "subscriptionGroups", "attributes": ["referenceName": "Fledge Pro"], "relationships": ["app": ref("apps", appID)],
        ]])["data"] as? [String: Any]
        try await call("POST", "/v1/subscriptionGroupLocalizations", ["data": [
            "type": "subscriptionGroupLocalizations", "attributes": ["name": "Fledge Pro", "locale": "en-US"],
            "relationships": ["subscriptionGroup": ref("subscriptionGroups", id(group ?? [:]))],
        ]])
        print("created subscription group Fledge Pro")
    } else {
        print("subscription group Fledge Pro exists")
    }
    let groupID = id(group ?? [:])

    // Each step checks what exists, so an interrupted run can simply be started again.
    let existingSubs = try await all("/v1/subscriptionGroups/\(groupID)/subscriptions")
    for plan in plans {
        var subID: String
        if let existing = existingSubs.first(where: { attrs($0)["productId"] as? String == plan.productID }) {
            subID = id(existing)
            print("\(plan.productID) exists (\(attrs(existing)["state"] ?? "?"))")
        } else {
            let created = try await call("POST", "/v1/subscriptions", ["data": [
                "type": "subscriptions",
                "attributes": ["name": plan.reference, "productId": plan.productID, "subscriptionPeriod": plan.period!,
                               "groupLevel": plan.level, "familySharable": false],
                "relationships": ["group": ref("subscriptionGroups", groupID)],
            ]])
            subID = id(created["data"] as? [String: Any] ?? [:])
            print("created \(plan.productID)")
        }

        if try await all("/v1/subscriptions/\(subID)/subscriptionLocalizations").isEmpty {
            try await call("POST", "/v1/subscriptionLocalizations", ["data": [
                "type": "subscriptionLocalizations",
                "attributes": ["name": plan.displayName, "description": plan.description, "locale": "en-US"],
                "relationships": ["subscription": ref("subscriptions", subID)],
            ]])
            print("  localization added")
        }

        let hasAvailability = (try? await call("GET", "/v1/subscriptions/\(subID)/subscriptionAvailability")).map { $0["data"] is [String: Any] } ?? false
        if !hasAvailability {
            try await call("POST", "/v1/subscriptionAvailabilities", ["data": [
                "type": "subscriptionAvailabilities", "attributes": ["availableInNewTerritories": true],
                "relationships": ["subscription": ref("subscriptions", subID),
                                  "availableTerritories": ["data": territories.map { ["type": "territories", "id": $0] }]],
            ]])
            print("  available in \(territories.count) territories")
        }

        // Price: the USA point at the planned price, then Apple's equalized points for every other territory.
        let priced = Set(try await all("/v1/subscriptions/\(subID)/prices?include=territory&limit=200").compactMap { price in
            (((price["relationships"] as? [String: Any])?["territory"] as? [String: Any])?["data"] as? [String: Any]).map(id)
        })
        let usPoints = try await all("/v1/subscriptions/\(subID)/pricePoints?filter[territory]=USA&limit=200")
        guard let usPoint = usPoints.first(where: { attrs($0)["customerPrice"] as? String == plan.price }) else {
            throw ASCError.setup("no USA price point at \(plan.price) for \(plan.productID)")
        }
        var points: [(territory: String, point: String)] = [("USA", id(usPoint))]
        for equal in try await all("/v1/subscriptionPricePoints/\(id(usPoint))/equalizations?limit=200&include=territory") {
            if let territory = ((equal["relationships"] as? [String: Any])?["territory"] as? [String: Any])?["data"] as? [String: Any] {
                points.append((id(territory), id(equal)))
            }
        }
        var added = 0
        for (territory, point) in points where !priced.contains(territory) {
            do {
                try await call("POST", "/v1/subscriptionPrices", ["data": [
                    "type": "subscriptionPrices", "attributes": ["preserveCurrentPrice": false],
                    "relationships": ["subscription": ref("subscriptions", subID),
                                      "subscriptionPricePoint": ref("subscriptionPricePoints", point),
                                      "territory": ref("territories", territory)],
                ]])
                added += 1
                if added % 25 == 0 { print("  prices: \(added)…") }
            } catch { print("  price \(territory): \(error)") }
        }
        print("  prices: \(priced.count) existed, \(added) added (\(points.count) territories)")

        if plan.freeTrial {
            let offered = Set(try await all("/v1/subscriptions/\(subID)/introductoryOffers?include=territory&limit=200").compactMap { offer in
                (((offer["relationships"] as? [String: Any])?["territory"] as? [String: Any])?["data"] as? [String: Any]).map(id)
            })
            var trials = 0, failures = 0
            for territory in territories where !offered.contains(territory) {
                do {
                    try await call("POST", "/v1/subscriptionIntroductoryOffers", ["data": [
                        "type": "subscriptionIntroductoryOffers",
                        "attributes": ["duration": "ONE_WEEK", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1],
                        "relationships": ["subscription": ref("subscriptions", subID), "territory": ref("territories", territory)],
                    ]])
                    trials += 1
                    if trials % 25 == 0 { print("  free trials: \(trials)…") }
                } catch {
                    failures += 1
                    if failures <= 2 { print("  free trial \(territory): \(error)") }
                }
            }
            print("  7-day free trial: \(offered.count) existed, \(trials) added, \(failures) failed")
        }
    }

    // Lifetime: a non-consumable.
    let existingIAPs = try await all("/v1/apps/\(appID)/inAppPurchasesV2?limit=200")
    if existingIAPs.contains(where: { attrs($0)["productId"] as? String == lifetime.productID }) {
        print("\(lifetime.productID) exists")
    } else {
        let created = try await call("POST", "/v2/inAppPurchases", ["data": [
            "type": "inAppPurchases",
            "attributes": ["name": lifetime.reference, "productId": lifetime.productID, "inAppPurchaseType": "NON_CONSUMABLE", "familySharable": false],
            "relationships": ["app": ref("apps", appID)],
        ]])
        let iapID = id(created["data"] as? [String: Any] ?? [:])
        print("created \(lifetime.productID)")
        try await call("POST", "/v1/inAppPurchaseLocalizations", ["data": [
            "type": "inAppPurchaseLocalizations",
            "attributes": ["name": lifetime.displayName, "description": lifetime.description, "locale": "en-US"],
            "relationships": ["inAppPurchaseV2": ref("inAppPurchases", iapID)],
        ]])
        let points = try await all("/v2/inAppPurchases/\(iapID)/pricePoints?filter[territory]=USA&limit=200")
        guard let point = points.first(where: { attrs($0)["customerPrice"] as? String == lifetime.price }) else {
            throw ASCError.setup("no USA price point at \(lifetime.price)")
        }
        try await call("POST", "/v1/inAppPurchasePriceSchedules", [
            "data": [
                "type": "inAppPurchasePriceSchedules",
                "relationships": ["inAppPurchase": ref("inAppPurchases", iapID), "baseTerritory": ref("territories", "USA"),
                                  "manualPrices": ["data": [["type": "inAppPurchasePrices", "id": "${base}"]]]],
            ],
            "included": [[
                "type": "inAppPurchasePrices", "id": "${base}", "attributes": ["startDate": NSNull()],
                "relationships": ["inAppPurchasePricePoint": ref("inAppPurchasePricePoints", id(point))],
            ]],
        ])
        print("  price \(lifetime.price) USD, other territories follow Apple's equalization")
        try await call("POST", "/v1/inAppPurchaseAvailabilities", ["data": [
            "type": "inAppPurchaseAvailabilities", "attributes": ["availableInNewTerritories": true],
            "relationships": ["inAppPurchase": ref("inAppPurchases", iapID),
                              "availableTerritories": ["data": territories.map { ["type": "territories", "id": $0] }]],
        ]])
        print("  available in \(territories.count) territories")
    }
}

// MARK: - Review requirements

/// Read-only: what App Store Connect still needs before review (category, age rating, content rights, price, contact, copyright).
func reviewStatus() async throws {
    let app = try await app()
    print("contentRightsDeclaration: \(attrs(app)["contentRightsDeclaration"] ?? "–")")
    let info = try await editableAppInfo(appID: id(app))
    let primary = try? await call("GET", "/v1/appInfos/\(id(info))/primaryCategory")
    print("primary category: \((primary?["data"] as? [String: Any]).map(id) ?? "–")")
    if let rating = try? await call("GET", "/v1/appInfos/\(id(info))/ageRatingDeclaration"),
       let data = rating["data"] as? [String: Any] {
        print("age rating declaration \(id(data)):")
        for (key, value) in attrs(data).sorted(by: { $0.key < $1.key }) { print("  \(key) = \(value)") }
    }
    // Read-only: the newest iOS version, editable or not.
    guard let version = items(try await call("GET", "/v1/apps/\(id(app))/appStoreVersions?filter[platform]=IOS&limit=1")).first else { return }
    print("version \(attrs(version)["versionString"] ?? "?"): \(attrs(version)["appStoreState"] ?? "?"), release: \(attrs(version)["releaseType"] ?? "–"), earliest: \(attrs(version)["earliestReleaseDate"] ?? "–")")
    print("copyright: \(attrs(version)["copyright"] ?? "–")")
    let build = await related("/v1/appStoreVersions/\(id(version))/build")
    print("build: \(build.map { attrs($0)["version"] ?? "?" } ?? "none")")
    let detail = try? await call("GET", "/v1/appStoreVersions/\(id(version))/appStoreReviewDetail")
    print("review detail: \((detail?["data"] as? [String: Any]).map { attrs($0).keys.sorted().joined(separator: ", ") } ?? "none")")
    let schedule = try? await call("GET", "/v1/apps/\(id(app))/appPriceSchedule")
    print("price schedule: \((schedule?["data"] as? [String: Any]).map(id) ?? "none")")
}

/// Sets what the review checklist needs and the app's facts decide: categories, content rights, age rating, free price.
/// Contact information and copyright come from a private file (see `reviewContact`).
func reviewSetup() async throws {
    let app = try await app()
    let appID = id(app)

    try await call("PATCH", "/v1/apps/\(appID)", ["data": ["type": "apps", "id": appID,
        "attributes": ["contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"]]])
    print("content rights: does not use third-party content")

    let info = try await editableAppInfo(appID: appID)
    try await call("PATCH", "/v1/appInfos/\(id(info))", ["data": ["type": "appInfos", "id": id(info), "relationships": [
        "primaryCategory": ref("appCategories", "HEALTH_AND_FITNESS"),
        "secondaryCategory": ref("appCategories", "PRODUCTIVITY"),
    ]]])
    print("categories: Health & Fitness, Productivity")

    // Age rating: no objectionable content; the app is about health habits, so "health or wellness topics" is yes.
    if let rating = (try await call("GET", "/v1/appInfos/\(id(info))/ageRatingDeclaration"))["data"] as? [String: Any] {
        let none = ["alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons", "horrorOrFearThemes",
                    "matureOrSuggestiveThemes", "medicalOrTreatmentInformation", "profanityOrCrudeHumor", "sexualContentGraphicAndNudity",
                    "sexualContentOrNudity", "violenceCartoonOrFantasy", "violenceRealistic", "violenceRealisticProlongedGraphicOrSadistic"]
        var answers: [String: Any] = Dictionary(uniqueKeysWithValues: none.map { ($0, "NONE") })
        for key in ["advertising", "ageAssurance", "gambling", "lootBox", "messagingAndChat", "parentalControls",
                    "socialMedia", "unrestrictedWebAccess", "userGeneratedContent"] { answers[key] = false }
        answers["healthOrWellnessTopics"] = true
        try await call("PATCH", "/v1/ageRatingDeclarations/\(id(rating))", ["data": ["type": "ageRatingDeclarations", "id": id(rating), "attributes": answers]])
        print("age rating answered (all none; health or wellness topics: yes)")
    }

    // Price: free (the money is in Fledge Pro).
    let points = try await all("/v1/apps/\(appID)/appPricePoints?filter[territory]=USA&limit=200")
    guard let free = points.first(where: { Double(attrs($0)["customerPrice"] as? String ?? "") == 0 }) else { throw ASCError.setup("no free price point") }
    try await call("POST", "/v1/appPriceSchedules", [
        "data": ["type": "appPriceSchedules", "relationships": [
            "app": ref("apps", appID), "baseTerritory": ref("territories", "USA"),
            "manualPrices": ["data": [["type": "appPrices", "id": "${free}"]]],
        ]],
        "included": [["type": "appPrices", "id": "${free}", "attributes": ["startDate": NSNull()],
                      "relationships": ["appPricePoint": ref("appPricePoints", id(free))]]],
    ])
    print("price: free")
}

/// App Review contact and copyright from a private JSON file that never goes into git (default Configuration/review-contact.json):
/// {"firstName": "", "lastName": "", "phone": "+40…", "email": "", "copyright": "2026 Name", "notes": ""}
func reviewContact(_ file: String) async throws {
    let info = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: file))) as? [String: String] ?? [:]
    let app = try await app()
    let version = try await editableVersion(appID: id(app))
    if let copyright = info["copyright"] {
        try await call("PATCH", "/v1/appStoreVersions/\(id(version))", ["data": ["type": "appStoreVersions", "id": id(version), "attributes": ["copyright": copyright]]])
        print("copyright set")
    }
    let attributes: [String: Any] = [
        "contactFirstName": info["firstName"] ?? "", "contactLastName": info["lastName"] ?? "",
        "contactPhone": info["phone"] ?? "", "contactEmail": info["email"] ?? "",
        "demoAccountRequired": false, "notes": info["notes"] ?? "",
    ]
    if let existing = (try? await call("GET", "/v1/appStoreVersions/\(id(version))/appStoreReviewDetail"))?["data"] as? [String: Any] {
        try await call("PATCH", "/v1/appStoreReviewDetails/\(id(existing))", ["data": ["type": "appStoreReviewDetails", "id": id(existing), "attributes": attributes]])
    } else {
        try await call("POST", "/v1/appStoreReviewDetails", ["data": ["type": "appStoreReviewDetails", "attributes": attributes,
            "relationships": ["appStoreVersion": ref("appStoreVersions", id(version))]]])
    }
    print("App Review contact set (no demo account needed)")
}

// MARK: - In-app purchase review details

/// Uploads one file through App Store Connect's reserve → upload operations → commit flow.
func uploadAsset(type: String, relationship: String, relatedType: String, relatedID: String, file: URL) async throws {
    let data = try Data(contentsOf: file)
    let reserved = try await call("POST", "/v1/\(type)", ["data": [
        "type": type, "attributes": ["fileName": file.lastPathComponent, "fileSize": data.count],
        "relationships": [relationship: ref(relatedType, relatedID)],
    ]])
    guard let asset = reserved["data"] as? [String: Any],
          let operations = attrs(asset)["uploadOperations"] as? [[String: Any]] else { throw ASCError.setup("no upload operations for \(type)") }
    for operation in operations {
        guard let url = (operation["url"] as? String).flatMap(URL.init(string:)),
              let offset = operation["offset"] as? Int, let length = operation["length"] as? Int else { continue }
        var request = URLRequest(url: url)
        request.httpMethod = operation["method"] as? String ?? "PUT"
        for header in operation["requestHeaders"] as? [[String: String]] ?? [] {
            if let name = header["name"], let value = header["value"] { request.setValue(value, forHTTPHeaderField: name) }
        }
        let (_, response) = try await URLSession.shared.upload(for: request, from: data.subdata(in: offset..<(offset + length)))
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw ASCError.http(code, "upload of \(file.lastPathComponent)") }
    }
    let checksum = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    try await call("PATCH", "/v1/\(type)/\(id(asset))", ["data": [
        "type": type, "id": id(asset), "attributes": ["uploaded": true, "sourceFileChecksum": checksum],
    ]])
}

let reviewNote = """
Fledge Pro unlocks Apple Health auto-completion for all three habits (free includes one), every widget size, Lock Screen widgets, \
app icons and CSV export. Open the paywall from Settings › Fledge Pro, from the banner in Add a habit when a second Health habit is \
chosen, or at the end of onboarding. No account or login is needed.
"""

func related(_ path: String) async -> [String: Any]? {
    ((try? await call("GET", path))?["data"]) as? [String: Any]
}

func iapStatus() async throws {
    let appID = id(try await app())
    for group in try await all("/v1/apps/\(appID)/subscriptionGroups") {
        let names = try await all("/v1/subscriptionGroups/\(id(group))/subscriptionGroupLocalizations").map { "\(attrs($0)["locale"] ?? "?"): \(attrs($0)["name"] ?? "?")" }
        print("group \(attrs(group)["referenceName"] ?? "?") – display names: \(names.isEmpty ? "NONE" : names.joined(separator: ", "))")
        for sub in try await all("/v1/subscriptionGroups/\(id(group))/subscriptions") {
            let locs = try await all("/v1/subscriptions/\(id(sub))/subscriptionLocalizations").count
            let prices = try await all("/v1/subscriptions/\(id(sub))/prices?limit=200").count
            let shot = await related("/v1/subscriptions/\(id(sub))/appStoreReviewScreenshot")
            let shotState = (shot.flatMap { attrs($0)["assetDeliveryState"] as? [String: Any] })?["state"] ?? (shot == nil ? "none" : "?")
            let note = (attrs(sub)["reviewNote"] as? String)?.isEmpty == false ? "yes" : "no"
            print("  \(attrs(sub)["productId"] ?? "?"): \(attrs(sub)["state"] ?? "?"), localizations \(locs), prices \(prices), review screenshot \(shotState), note \(note)")
            let territories = await related("/v1/subscriptions/\(id(sub))/subscriptionAvailability")
            let names = try await all("/v1/subscriptions/\(id(sub))/subscriptionLocalizations").map { "\(attrs($0)["name"] ?? "?")" }
            print("    reference \(attrs(sub)["name"] ?? "?"), period \(attrs(sub)["subscriptionPeriod"] ?? "?"), level \(attrs(sub)["groupLevel"] ?? "?"), family sharing \(attrs(sub)["familySharable"] ?? "–"), availability \(territories == nil ? "none" : "set"), store name \(names.joined())")
        }
    }
    for product in try await all("/v1/apps/\(appID)/inAppPurchasesV2?limit=200") {
        let locs = try await all("/v2/inAppPurchases/\(id(product))/inAppPurchaseLocalizations").count
        let schedule = await related("/v2/inAppPurchases/\(id(product))/iapPriceSchedule")
        let shot = await related("/v2/inAppPurchases/\(id(product))/appStoreReviewScreenshot")
        let shotState = (shot.flatMap { attrs($0)["assetDeliveryState"] as? [String: Any] })?["state"] ?? (shot == nil ? "none" : "?")
        let note = (attrs(product)["reviewNote"] as? String)?.isEmpty == false ? "yes" : "no"
        print("  \(attrs(product)["productId"] ?? "?"): \(attrs(product)["state"] ?? "?"), localizations \(locs), price schedule \(schedule == nil ? "none" : "yes"), review screenshot \(shotState), note \(note)")
        let territories = await related("/v2/inAppPurchases/\(id(product))/inAppPurchaseAvailability")
        print("    reference \(attrs(product)["name"] ?? "?"), family sharing \(attrs(product)["familySharable"] ?? "–"), availability \(territories == nil ? "none" : "set")")
    }
}

/// Adds the App Review screenshot (replacing an existing one) and the review note to every Fledge Pro product.
func iapReview(_ file: String) async throws {
    let url = URL(fileURLWithPath: file)
    guard FileManager.default.fileExists(atPath: url.path) else { throw ASCError.setup("no screenshot at \(file)") }
    let appID = id(try await app())
    for group in try await all("/v1/apps/\(appID)/subscriptionGroups") {
        for sub in try await all("/v1/subscriptionGroups/\(id(group))/subscriptions") {
            if let old = await related("/v1/subscriptions/\(id(sub))/appStoreReviewScreenshot") {
                try await call("DELETE", "/v1/subscriptionAppStoreReviewScreenshots/\(id(old))")
            }
            try await uploadAsset(type: "subscriptionAppStoreReviewScreenshots", relationship: "subscription",
                                  relatedType: "subscriptions", relatedID: id(sub), file: url)
            try await call("PATCH", "/v1/subscriptions/\(id(sub))", ["data": ["type": "subscriptions", "id": id(sub), "attributes": ["reviewNote": reviewNote]]])
            print("\(attrs(sub)["productId"] ?? "?"): review screenshot + note")
        }
    }
    for product in try await all("/v1/apps/\(appID)/inAppPurchasesV2?limit=200") {
        if let old = await related("/v2/inAppPurchases/\(id(product))/appStoreReviewScreenshot") {
            try await call("DELETE", "/v1/inAppPurchaseAppStoreReviewScreenshots/\(id(old))")
        }
        try await uploadAsset(type: "inAppPurchaseAppStoreReviewScreenshots", relationship: "inAppPurchaseV2",
                              relatedType: "inAppPurchases", relatedID: id(product), file: url)
        try await call("PATCH", "/v2/inAppPurchases/\(id(product))", ["data": ["type": "inAppPurchases", "id": id(product), "attributes": ["reviewNote": reviewNote]]])
        print("\(attrs(product)["productId"] ?? "?"): review screenshot + note")
    }
}

/// Read-only: open review submissions and what's in them.
func submissionStatus() async throws {
    let appID = id(try await app())
    for submission in try await all("/v1/reviewSubmissions?filter[app]=\(appID)&limit=20") {
        let a = attrs(submission)
        guard a["state"] as? String != "COMPLETE" else { continue }
        print("submission \(id(submission)): \(a["state"] ?? "?"), platform \(a["platform"] ?? "–")")
        let raw = try await call("GET", "/v1/reviewSubmissions/\(id(submission))/items?limit=50&include=appStoreVersion")
        for item in items(raw) {
            let rels = (item["relationships"] as? [String: Any]) ?? [:]
            let linked = rels.compactMap { key, value -> String? in
                guard let data = (value as? [String: Any])?["data"] as? [String: Any] else { return nil }
                return "\(key)=\(data["id"] ?? "?")"
            }
            print("  item \(attrs(item)["state"] ?? "?"): \(linked.joined(separator: ", "))")
        }
        for included in raw["included"] as? [[String: Any]] ?? [] {
            print("  includes \(included["type"] ?? "?") \(attrs(included)["versionString"] ?? id(included))")
        }
    }
    for group in try await all("/v1/apps/\(appID)/subscriptionGroups") {
        print("group \(id(group)) \(attrs(group)["referenceName"] ?? "?")")
        for sub in try await all("/v1/subscriptionGroups/\(id(group))/subscriptions") {
            print("  \(id(sub)) \(attrs(sub)["productId"] ?? "?"): \(attrs(sub)["state"] ?? "?")")
        }
    }
}

// MARK: - Builds

func builds() async throws {
    let appID = id(try await app())
    for build in try await all("/v1/builds?filter[app]=\(appID)&sort=-uploadedDate&limit=10&include=preReleaseVersion") {
        let a = attrs(build)
        print("build \(a["version"] ?? "?"): \(a["processingState"] ?? "?"), uploaded \(a["uploadedDate"] ?? "?")")
    }
}

func attachBuild(_ number: String) async throws {
    let appID = id(try await app())
    let version = try await editableVersion(appID: appID)
    guard let build = try await all("/v1/builds?filter[app]=\(appID)&filter[version]=\(number)").first else {
        throw ASCError.setup("no build \(number) yet")
    }
    guard attrs(build)["processingState"] as? String == "VALID" else {
        throw ASCError.setup("build \(number) is \(attrs(build)["processingState"] ?? "?"); wait until VALID")
    }
    try await call("PATCH", "/v1/appStoreVersions/\(id(version))/relationships/build", ref("builds", id(build)))
    print("build \(number) attached to version \(attrs(version)["versionString"] ?? "?")")
}

let arguments = CommandLine.arguments.dropFirst()
do {
    switch arguments.first {
    case "status": try await status()
    case "metadata": try await metadata(arguments.dropFirst().first ?? "Design/AppStore/metadata.en-US.json")
    case "screenshots": try await screenshots()
    case "iap": try await iap()
    case "builds": try await builds()
    case "iap-status": try await iapStatus()
    case "submission-status": try await submissionStatus()
    case "iap-review": try await iapReview(arguments.dropFirst().first ?? "/tmp/fledge-paywall-review.png")
    case "review-status": try await reviewStatus()
    case "review-setup": try await reviewSetup()
    case "review-contact": try await reviewContact(arguments.dropFirst().first ?? "Configuration/review-contact.json")
    case "attach-build": try await attachBuild(arguments.dropFirst().first ?? "")
    default: print("usage: swift scripts/asc.swift status | metadata [file.json] | screenshots")
    }
} catch {
    print("error: \(error)")
    exit(1)
}
