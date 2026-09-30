import Foundation
import Testing

@testable import scip_swift

/// These probes use the builder API present in v0.3.0, so the baseline fails assertions,
/// rather than failing to compile because a new test seam is missing.
@Suite("Integration: source ranges and identity")
struct SourceIdentityIntegrationTests {
  private func build() throws -> Scip_Index {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let fixture = root.appendingPathComponent("Fixtures/SourceIdentityFixture").path
    let work = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("source-identity-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: work) }
    let result = try SwiftPMBuildRunner(
      repoPath: fixture, configuration: .debug,
      scratchPath: work.appendingPathComponent("build").path
    ).produceIndexStore()
    return try SCIPIndexBuilder(
      repoPath: fixture, indexStorePath: result.indexStorePath,
      databasePath: work.appendingPathComponent("db").path,
      buildToolName: "swiftpm", converterVersion: "test", demangle: false
    ).build()
  }

  @Test("definition occurrences enclose the complete method body")
  func declarationRanges() throws {
    let index = try build()
    let method = try #require(index.documents.flatMap(\.occurrences).first {
      $0.symbol == "scip-swift swiftpm SourceIdentityFixture . Probe#read()."
        && $0.symbolRoles & 1 != 0
    })
    #expect(method.enclosingRange == [9, 2, 11, 3])
  }

  @Test("private properties and file-private variables remain distinct at definitions and uses")
  func privateIdentities() throws {
    let index = try build()
    var loggers: Set<String> = []
    var properties: Set<String> = []
    let names: Set<String> = ["first", "second", "third", "fourth", "fifth", "sixth"]
    for document in index.documents {
      for info in document.symbols where info.displayName == "logger" || names.contains(info.displayName) {
        if info.displayName == "logger" { loggers.insert(info.symbol) }
        else { properties.insert(info.symbol) }
        #expect(document.occurrences.contains { $0.symbol == info.symbol && $0.symbolRoles & 1 == 0 })
      }
    }
    #expect(loggers.count == 3)
    #expect(properties.count == 6)
  }

  @Test("every relationship target resolves even without a source occurrence")
  func relationshipTargets() throws {
    let index = try build()
    let information = index.documents.flatMap(\.symbols) + index.externalSymbols
    let known = Set(information.map(\.symbol))
    let occurrences = Set(index.documents.flatMap(\.occurrences).map(\.symbol))
    let targets = Set(index.documents.flatMap(\.symbols).flatMap(\.relationships).map(\.symbol))
    #expect(!targets.subtracting(occurrences).isEmpty)
    #expect(targets.isSubset(of: known))
  }

  @Test("projected getter anchors cover the source token and stay within its line")
  func projectedRanges() throws {
    let index = try build()
    let document = try #require(index.documents.first { $0.relativePath.hasSuffix("/Probe.swift") })
    let projected = document.occurrences.filter { $0.singleLineRange.line == 10 }
    #expect(!projected.isEmpty)
    for occurrence in projected {
      #expect(occurrence.singleLineRange.startCharacter == 4)
      #expect(occurrence.singleLineRange.endCharacter == 14)
    }
  }
}
