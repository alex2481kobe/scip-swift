import IndexStoreDB
import Testing

@testable import scip_swift

@Suite("Compiler symbol identity")
struct SymbolIdentityTests {
  @Test("private containers keep member names and unique private methods stay readable")
  func privateContext() throws {
    let usrs = [
      "s:4Demo4Rows33_9FDFC6611CE3A7DC2D18001A442C2491LLV5firstSbvp",
      "s:4Demo4Rows33_9FDFC6611CE3A7DC2D18001A442C2491LLV6secondSbvp",
      "s:4Demo6logger33_912A564A3D479FD49D33F6C0092EA616LLSivp",
      "s:4Demo6logger33_BBA9AA5C4DE8F7EF839EDA59634ADAA7LLSivp",
    ]
    for (usr, name) in zip(usrs, ["first", "second", "logger", "logger"]) {
      let parsed = try #require(USRSymbolParser.parse(usr))
      #expect(parsed.name == name)
      #expect(parsed.containers.map(\.name) == (name == "logger" ? [] : ["Rows"]))
    }
    let usr = "s:4Demo4ViewV13checkRollover33_40045E8B123456789012345678901234LLyyF"
    let parsed = try #require(USRSymbolParser.parse(usr))
    let symbol = Symbol(usr: usr, name: "checkRollover()", kind: .instanceMethod,
                        subKind: .none, language: .swift)
    #expect(USRSymbolMapper.canonicalSymbolString(
      parsed: parsed, symbol: symbol, isSystemLocation: false, toolchainVersion: "test")
      == "scip-swift swiftpm Demo . View#checkRollover().")
  }

  @Test("different extending modules cannot produce the same canonical member")
  func extensionContext() throws {
    var candidates: [SymbolIdentityTable.Candidate] = []
    for module in ["First", "Other"] {
      let usr = "s:SS5\(module)E4workyyF"
      let parsed = try #require(USRSymbolParser.parse(usr))
      let symbol = Symbol(usr: usr, name: "work()", kind: .instanceMethod,
                          subKind: .none, language: .swift)
      let canonical = try #require(USRSymbolMapper.canonicalSymbolString(
        parsed: parsed, symbol: symbol, isSystemLocation: false,
        toolchainVersion: "test"))
      #expect(canonical == "scip-swift swift Swift test String#work().")
      candidates.append(.init(usr: usr, canonical: canonical, fallback: "raw \(usr)"))
    }
    let table = SymbolIdentityTable(candidates: candidates)
    #expect(Set(table.symbolsByUSR.values).count == 2)
    #expect(table.symbolsByUSR.values.allSatisfy { $0.contains("String#work().id_") })
    #expect(table.fallbackUSRs.isEmpty)
  }

  @Test("inverse collisions remap every USR independent of occurrence order")
  func inverseCollisions() {
    let candidates: [SymbolIdentityTable.Candidate] = [
      .init(usr: "first", canonical: "same", fallback: "raw first"),
      .init(usr: "second", canonical: "same", fallback: "raw second"),
      .init(usr: "first", canonical: "same", fallback: "raw first"),
      .init(usr: "third", canonical: "unique", fallback: "raw third"),
    ]
    let table = SymbolIdentityTable(candidates: candidates)
    #expect(Set(table.symbolsByUSR.values).count == 3)
    #expect(table.symbolsByUSR["first"]?.hasPrefix("sameid_") == true)
    #expect(table.symbolsByUSR["second"]?.hasPrefix("sameid_") == true)
    #expect(table.symbolsByUSR["third"] == "unique")
    #expect(table.fallbackUSRs.isEmpty)
    let reversed = SymbolIdentityTable(candidates: Array(candidates.reversed()))
    #expect(reversed.symbolsByUSR == table.symbolsByUSR)
    #expect(reversed.cacheValidationFingerprint() == table.cacheValidationFingerprint())
  }

  @Test("shared discriminator prefixes and existing spellings never merge identities")
  func suffixCollisions() throws {
    let first = "s:4Demo6logger33_12345678AAAAAAAAAAAAAAAAAAAAAAAALLSivp"
    let second = "s:4Demo6logger33_12345678BBBBBBBBBBBBBBBBBBBBBBBBLLSivp"
    let canonical = "scip-swift swiftpm Demo . logger."
    let candidates: [SymbolIdentityTable.Candidate] = [
      .init(usr: first, canonical: canonical, fallback: "raw first"),
      .init(usr: second, canonical: canonical, fallback: "raw second"),
      .init(usr: "reserved", canonical: canonical + "id_12345678.", fallback: "raw third"),
    ]
    let table = SymbolIdentityTable(candidates: candidates)
    #expect(Set(table.symbolsByUSR.values).count == 3)
    #expect(table.symbolsByUSR["reserved"] == canonical + "id_12345678.")
    #expect(table.symbolsByUSR == SymbolIdentityTable(candidates: candidates.reversed()).symbolsByUSR)
  }
}
