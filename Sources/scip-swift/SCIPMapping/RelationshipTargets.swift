extension SCIPIndexBuilder {
  /// Relationship targets need SymbolInformation even when no occurrence mentions them.
  static func addRelationshipTargets(
    documents: [Scip_Document], externalSymbols: inout [String: Scip_SymbolInformation]
  ) {
    let defined = Set(documents.flatMap { $0.symbols.map(\.symbol) })
    for document in documents {
      for info in document.symbols {
        for relationship in info.relationships {
          let symbol = relationship.symbol
          guard !symbol.isEmpty, !symbol.hasPrefix("local "),
            !defined.contains(symbol), externalSymbols[symbol] == nil
          else { continue }
          var target = Scip_SymbolInformation()
          target.symbol = symbol
          externalSymbols[symbol] = target
        }
      }
    }
  }
}
