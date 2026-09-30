import Testing

@testable import scip_swift

@Suite("Relationship-only targets")
struct RelationshipTargetTests {
  @Test("targets without occurrences get external information without duplicating definitions")
  func relationshipOnlyTargets() {
    var target = Scip_Relationship()
    target.symbol = "external"
    target.isImplementation = true
    var local = Scip_Relationship()
    local.symbol = "defined"
    var info = Scip_SymbolInformation()
    info.symbol = "defined"
    info.relationships = [target, local, target]
    var document = Scip_Document()
    document.symbols = [info]
    var external: [String: Scip_SymbolInformation] = [:]
    SCIPIndexBuilder.addRelationshipTargets(documents: [document], externalSymbols: &external)
    #expect(Set(external.keys) == ["external"])
    #expect(external["external"]?.symbol == "external")
    #expect(document.occurrences.isEmpty)
  }
}
