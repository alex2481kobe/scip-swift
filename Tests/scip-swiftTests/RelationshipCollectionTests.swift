import Testing

@testable import scip_swift

@Suite("Relationship collection")
struct RelationshipCollectionTests {
  @Test("union deduplicates targets, preserves flags and has deterministic order")
  func union() {
    var reference = Scip_Relationship()
    reference.symbol = "target"
    reference.isReference = true
    var implementation = Scip_Relationship()
    implementation.symbol = "target"
    implementation.isImplementation = true
    implementation.isDefinition = true
    implementation.isTypeDefinition = true
    var other = Scip_Relationship()
    other.symbol = "another"
    other.isImplementation = true
    let edges = [reference, other, implementation, reference]
    let union = RelationshipMapping.union(edges)
    #expect(union.map(\.symbol) == ["another", "target"])
    #expect(union[1].isReference && union[1].isImplementation)
    #expect(union[1].isDefinition && union[1].isTypeDefinition)
    #expect(union == RelationshipMapping.union(edges.reversed()))
  }

  @Test("last definition selection cannot discard the collected union")
  func lastDefinition() {
    var edge = Scip_Relationship()
    edge.symbol = "requirement"
    edge.isReference = true
    edge.isImplementation = true
    var first = Scip_SymbolInformation()
    first.symbol = "witness"
    first.documentation = ["first"]
    first.relationships = [edge]
    var last = first
    last.documentation = ["last"]
    last.relationships = []
    let winner = SCIPIndexBuilder.winningSymbolInformation([
      (first, .init(relativePath: "A.swift", line: 1, utf8Column: 1)),
      (last, .init(relativePath: "A.swift", line: 2, utf8Column: 1)),
    ])
    var document = Scip_Document()
    document.symbols = [winner]
    SCIPIndexBuilder.applyRelationships(["witness": [edge], "undefined": [edge]], to: &document)
    #expect(document.symbols.map(\.symbol) == ["witness"])
    #expect(document.symbols[0].documentation == ["last"])
    #expect(document.symbols[0].relationships == [edge])
    #expect(document.occurrences.isEmpty)
  }
}
