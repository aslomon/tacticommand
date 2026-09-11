import Foundation
import XCTest

@testable import CreatorMicroCore

func makeConfigurationStore(containing configuration: MicroConfiguration) throws
    -> ConfigurationStore
{
    let location = makeTemporaryConfigurationDirectory().appendingPathComponent("config.json")
    try FileManager.default.createDirectory(
        at: location.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try JSONEncoder().encode(configuration).write(to: location)
    return ConfigurationStore(fileURL: location)
}

func assertInvalidConfigurationResult<T>(
    _ result: Result<T, ConfigurationStoreError>,
    containing text: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard case .failure(let error) = result else {
        return XCTFail("Expected configuration validation to fail", file: file, line: line)
    }
    XCTAssertTrue(
        error.localizedDescription.localizedCaseInsensitiveContains(text),
        file: file,
        line: line
    )
}

func makeTemporaryConfigurationDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}
