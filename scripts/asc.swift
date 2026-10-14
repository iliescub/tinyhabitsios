// App Store Connect API for Fledge's listing (MKT-6, REL-2). Never prints the key or the token.
//
// Usage (run through scripts/watchdog.sh):
//   swift scripts/asc.swift status                 read-only: app, versions, current subtitle/keywords, screenshot sets
//   swift scripts/asc.swift metadata [file.json]   subtitle (app info) + description, keywords, promotional text (version)
//   swift scripts/asc.swift screenshots            replaces the iPhone 6.9" and iPad 13" sets with Design/AppStore/*.png
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
}

func metadata(_ file: String) async throws {
    let meta = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: file))) as? [String: String] ?? [:]
    let locale = meta["locale"] ?? "en-US"
    let app = try await app()

    let info = try await editableAppInfo(appID: id(app))
    if let subtitle = meta["subtitle"],
       let loc = items(try await call("GET", "/v1/appInfos/\(id(info))/appInfoLocalizations")).first(where: { attrs($0)["locale"] as? String == locale }) {
        try await call("PATCH", "/v1/appInfoLocalizations/\(id(loc))", ["data": ["type": "appInfoLocalizations", "id": id(loc), "attributes": ["subtitle": subtitle]]])
        print("subtitle set: \(subtitle)")
    }

    let version = try await editableVersion(appID: id(app))
    let loc = try await versionLocalization(versionID: id(version), locale: locale)
    var fields: [String: String] = [:]
    for key in ["description", "keywords", "promotionalText"] { if let value = meta[key] { fields[key] = value } }
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

let arguments = CommandLine.arguments.dropFirst()
do {
    switch arguments.first {
    case "status": try await status()
    case "metadata": try await metadata(arguments.dropFirst().first ?? "Design/AppStore/metadata.en-US.json")
    case "screenshots": try await screenshots()
    default: print("usage: swift scripts/asc.swift status | metadata [file.json] | screenshots")
    }
} catch {
    print("error: \(error)")
    exit(1)
}
