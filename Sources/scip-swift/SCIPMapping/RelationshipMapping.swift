import IndexStoreDB

/// Requirement: IndexStoreDB to SCIP protobuf conversion — relationship mapping (META-01).
///
/// Maps IndexStoreDB `SymbolRelation` entries to SCIP `Scip_Relationship` messages.
///
/// Spike findings (META-06): Swift's IndexStoreDB populates relations on member
/// occurrences (methods, properties, initializers), not on type-level definitions.
/// The key relation roles populated for Swift are:
///   - `.overrideOf` — overriding method → superclass method (maps to is_reference + is_implementation)
///   - `.childOf` — member → containing type (used for enclosing_symbol, NOT relationships)
///
/// Type-level inheritance (class Dog: Animal) does NOT produce `.baseOf` or `.extendedBy`
/// relations for Swift code. Protocol conformance also does not produce type-level
/// relations. Relationship mapping is therefore limited to override relationships.
enum RelationshipMapping {
  /// One edge per target, retaining every flag and independent of occurrence order.
  static func union(_ relationships: [Scip_Relationship]) -> [Scip_Relationship] {
    var targets: [String: Scip_Relationship] = [:]
    for relationship in relationships {
      var merged = targets[relationship.symbol] ?? relationship
      merged.isReference = merged.isReference || relationship.isReference
      merged.isImplementation = merged.isImplementation || relationship.isImplementation
      merged.isTypeDefinition = merged.isTypeDefinition || relationship.isTypeDefinition
      merged.isDefinition = merged.isDefinition || relationship.isDefinition
      targets[relationship.symbol] = merged
    }
    return targets.values.sorted { $0.symbol < $1.symbol }
  }

  static func scipRelationships(
    for relations: [SymbolRelation],
    symbolFormatter: (Symbol) -> String
  ) -> [Scip_Relationship] {
    relations.compactMap { relation in
      if relation.roles.contains(.childOf) {
        return nil
      }

      var rel = Scip_Relationship()
      rel.symbol = symbolFormatter(relation.symbol)

      if relation.roles.contains(.overrideOf) {
        rel.isReference = true
        rel.isImplementation = true
      }

      if !rel.isReference && !rel.isImplementation && !rel.isTypeDefinition && !rel.isDefinition {
        return nil
      }

      return rel
    }
  }
}
