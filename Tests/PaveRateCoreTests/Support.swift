import XCTest

func expectClose(
    _ actual: Double,
    _ expected: Double,
    digits: Int,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let accuracy = pow(10.0, Double(-digits)) / 2
    XCTAssertEqual(actual, expected, accuracy: accuracy, file: file, line: line)
}

func asphaltConfigYAML(file: StaticString = #filePath) throws -> String {
    let source = URL(fileURLWithPath: "\(file)")
    let root = source
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let yaml = root.appendingPathComponent("Config/paverate-asphalt.yaml")
    return try String(contentsOf: yaml, encoding: .utf8)
}

func yamlValue(under heading: String, in yaml: String) -> Double? {
    let pattern = "(?m)^  \(NSRegularExpression.escapedPattern(for: heading)):\\n    value: ([0-9.]+)"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(yaml.startIndex..., in: yaml)
    guard let match = regex.firstMatch(in: yaml, range: range),
          let valueRange = Range(match.range(at: 1), in: yaml) else { return nil }
    return Double(yaml[valueRange])
}
