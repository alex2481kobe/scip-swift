import Foundation
import IndexStoreDB

/// Resolve identities before emitting documents, including reference-only and relation-only
/// symbols. Only canonical collisions receive a short discriminator descriptor.
struct SymbolIdentityTable {
  struct Candidate {
    let usr: String
    let canonical: String
    let fallback: String
  }

  let symbolsByUSR: [String: String]
  let fallbackUSRs: Set<String>

  init(candidates: [Candidate]) {
    // Normalize location-module variants before detecting collisions: one USR is one identity.
    var canonicalByUSR: [String: String] = [:]
    for candidate in candidates {
      canonicalByUSR[candidate.usr] = min(
        canonicalByUSR[candidate.usr] ?? candidate.canonical, candidate.canonical)
    }
    var groups: [String: [String]] = [:]
    for (usr, canonical) in canonicalByUSR { groups[canonical, default: []].append(usr) }
    var symbols = canonicalByUSR
    var reserved = Set(canonicalByUSR.values)
    for (canonical, usrs) in groups.sorted(by: { $0.key < $1.key }) where usrs.count > 1 {
      for usr in usrs.sorted() {
        let digest = ContentHasher.sha256Hex(of: Data(usr.utf8))
        let discriminator = String((Self.privateDiscriminator(in: usr) ?? digest).prefix(8))
        let base = canonical + "id_" + discriminator
        var resolved = base + "."
        // Distinct declarations can share a private discriminator or its short prefix.
        // Check generated spellings against each other AND existing canonical symbols.
        var ordinal = 1
        while reserved.contains(resolved) {
          resolved = base + "_\(ordinal)."
          ordinal += 1
        }
        symbols[usr] = resolved
        reserved.insert(resolved)
      }
    }
    symbolsByUSR = symbols
    fallbackUSRs = Set(candidates.filter { symbols[$0.usr] == $0.fallback }.map(\.usr))
  }

  private static func privateDiscriminator(in usr: String) -> String? {
    guard let range = usr.range(of: "_[0-9A-Fa-f]{32}LL", options: .regularExpression) else {
      return nil
    }
    return String(usr[range].dropFirst().dropLast(2))
  }

  func cacheValidationFingerprint() -> String {
    let entries = symbolsByUSR.sorted { $0.key < $1.key }
      .map { $0.key + "\u{0}" + $0.value }.joined(separator: "\u{1}")
    return ContentHasher.sha256Hex(of: Data(entries.utf8))
  }
}

extension SCIPIndexBuilder {
  func buildIdentityTable(indexStoreDB: IndexStoreDB, overloadTable: OverloadTable) -> SymbolIdentityTable {
    var candidates: [SymbolIdentityTable.Candidate] = []
    for path in SwiftFileDiscovery.swiftFiles(underRepoPath: repoPath) {
      for occurrence in indexStoreDB.symbolOccurrences(inFilePath: path) {
        for symbol in [occurrence.symbol] + occurrence.relations.map(\.symbol)
        where !symbol.properties.contains(.local) {
          let canonical = canonicalSymbolString(
            for: symbol,
            isSystemLocation: occurrence.location.isSystem,
            locationModuleName: occurrence.location.moduleName,
            overloadIndex: overloadTable.index(forUSR: symbol.usr)
          )
          let fallback = SCIPSymbolFormatter.fallbackSymbolString(
            isSystem: occurrence.location.isSystem,
            moduleName: occurrence.location.moduleName,
            toolchainVersion: ToolchainInfo.pinnedSwiftVersion,
            usr: symbol.usr
          )
          candidates.append(.init(usr: symbol.usr, canonical: canonical, fallback: fallback))
        }
      }
    }
    return SymbolIdentityTable(candidates: candidates)
  }
}
