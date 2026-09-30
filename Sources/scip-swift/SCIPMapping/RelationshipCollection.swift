import IndexStoreDB

extension SCIPIndexBuilder {
  /// Witness relations can live on non-definition occurrences at extension anchors,
  /// including in other files. Collect by compiler identity before emitting any document.
  func collectRelationships(
    indexStoreDB: IndexStoreDB, overloadTable: OverloadTable,
    identityTable: SymbolIdentityTable
  ) -> [String: [Scip_Relationship]] {
    var byUSR: [String: [Scip_Relationship]] = [:]
    for path in SwiftFileDiscovery.swiftFiles(underRepoPath: repoPath) {
      for occurrence in indexStoreDB.symbolOccurrences(inFilePath: path)
      where !occurrence.symbol.properties.contains(.local) {
        let mapped = RelationshipMapping.scipRelationships(for: occurrence.relations) { symbol in
          canonicalSymbolString(
            for: symbol, isSystemLocation: occurrence.location.isSystem,
            locationModuleName: occurrence.location.moduleName,
            overloadIndex: overloadTable.index(forUSR: symbol.usr), identityTable: identityTable)
        }
        if !mapped.isEmpty {
          byUSR[occurrence.symbol.usr, default: []].append(contentsOf: mapped)
        }
      }
    }
    var bySymbol: [String: [Scip_Relationship]] = [:]
    for (usr, relationships) in byUSR {
      guard let symbol = identityTable.symbolsByUSR[usr] else { continue }
      bySymbol[symbol] = RelationshipMapping.union(relationships)
    }
    return bySymbol
  }

  /// Only existing defining information receives relationships; no occurrence or extent
  /// is created or changed. Replacement also clears stale relationships in cached documents.
  static func applyRelationships(
    _ relationships: [String: [Scip_Relationship]], to document: inout Scip_Document
  ) {
    for i in document.symbols.indices where !document.symbols[i].symbol.hasPrefix("local ") {
      document.symbols[i].relationships = relationships[document.symbols[i].symbol] ?? []
    }
  }
}
