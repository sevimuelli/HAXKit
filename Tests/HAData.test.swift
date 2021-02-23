@testable import HAWebSocket
import XCTest

internal class HADataTests: XCTestCase {
    func testDictionary() {
        let data = HAData(value: ["test": true])
        guard case let .dictionary(value) = data else {
            XCTFail("expected dictionary to product dictionary")
            return
        }

        XCTAssertEqual(value["test"] as? Bool, true)
    }

    func testArray() throws {
        let data = HAData(value: [
            ["inner_test": 1],
            ["inner_test": 2],
        ])

        guard case let .array(value) = data else {
            XCTFail("expected array to product array")
            return
        }

        XCTAssertEqual(value.count, 2)
        guard case let .dictionary(value1) = try value.get(throwing: 0),
              case let .dictionary(value2) = try value.get(throwing: 1) else {
            XCTFail("expected dictionary elements")
            return
        }

        XCTAssertEqual(value1["inner_test"] as? Int, 1)
        XCTAssertEqual(value2["inner_test"] as? Int, 2)
    }

    func testEmpty() {
        for value: Any? in [
            true, 3, (), nil,
        ] {
            let data = HAData(value: value)
            switch data {
            case .empty: break // pass
            default: XCTFail("expected empty, got \(data)")
            }
        }
    }

    func testDecodeMissingKey() {
        let value = HAData(value: ["key": "value"])
        XCTAssertThrowsError(try value.decode("missing") as String) { error in
            XCTAssertEqual(error as? HADataError, .missingKey("missing"))
        }
    }

    func testDecodeConvertable() throws {
        let value = HAData(value: ["key": "value"])
        XCTAssertEqual(try value.decode("key"), "value")
    }

    func testDecodeNotConvertable() {
        let value = HAData(value: ["key": false])
        XCTAssertThrowsError(try value.decode("key") as String) { error in
            XCTAssertEqual(error as? HADataError, .incorrectType(
                key: "key",
                expected: String(describing: String.self),
                actual: String(describing: Bool.self)
            ))
        }
    }

    func testDecodeToData() throws {
        let value = HAData(value: ["key": ["value": true]])
        let keyValue: HAData = try value.decode("key")
        guard case let .dictionary(innerValue) = keyValue else {
            XCTFail("expected data wrapping dictionary")
            return
        }
        XCTAssertEqual(innerValue["value"] as? Bool, true)
    }

    func testDecodeToArrayOfData() throws {
        let value = HAData(value: ["key": [["inner": 1], ["inner": 2]]])
        let keyValue: [HAData] = try value.decode("key")
        XCTAssertEqual(try keyValue.get(throwing: 0).decode("inner") as Int, 1)
        XCTAssertEqual(try keyValue.get(throwing: 1).decode("inner") as Int, 2)
    }

    func testDecodeToDateWithNonDictionary() throws {
        let value = HAData(value: nil)
        XCTAssertThrowsError(try value.decode("some_key") as Date) { error in
            XCTAssertEqual(error as? HADataError, .missingKey("some_key"))
        }
    }

    func testDecodeToDateWithMissingKey() throws {
        let value = HAData(value: [:])
        XCTAssertThrowsError(try value.decode("some_key") as Date) { error in
            XCTAssertEqual(error as? HADataError, .missingKey("some_key"))
        }
    }

    func testDecodeToDate() throws {
        let value = HAData(value: ["some_key": "2021-02-20T05:14:52.647932+00:00"])
        let date: Date = try value.decode("some_key")

        let components = Calendar.current.dateComponents(
            in: TimeZone(identifier: "UTC+6")!,
            from: date
        )
        XCTAssertEqual(components.year, 2021)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 20)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 14)
        XCTAssertEqual(components.second, 52)
        XCTAssertEqual(components.nanosecond ?? -1, 647_000_000, accuracy: 100_000)
    }

    func testDecodeToDateWithInvalidString() throws {
        for dateString in [
            // no milliseconds
            "2021-02-20 05:14:52 +0000",
            // no offset
            "2021-02-20T05:14:52.647932",
            // no time
            "2021-02-20",
        ] {
            let value = HAData(value: ["some_key": dateString])
            XCTAssertThrowsError(try value.decode("some_key") as Date) { error in
                XCTAssertEqual(error as? HADataError, .incorrectType(
                    key: "some_key",
                    expected: String(describing: Date.self),
                    actual: String(describing: String.self)
                ))
            }
        }
    }

    func testDecodeWithTransform() throws {
        let value = HAData(value: ["name": "zacwest"])
        let result: Int = try value.decode("name", transform: { (underlying: String) in
            underlying.count
        })
        XCTAssertEqual(result, 7)
    }

    func testDecodeWithThrowingTransform() throws {
        let value = HAData(value: ["name": "zacwest"])
        XCTAssertThrowsError(try value.decode("name", transform: { (_: String) in
            nil
        }) as Int) { error in
            XCTAssertEqual(error as? HADataError, .couldntTransform(key: "name"))
        }
    }

    func testDecodeWithFallbackWithIncorrectType() throws {
        let value = HAData(value: ["name": "zacwest"])
        XCTAssertEqual(value.decode("name", fallback: 3) as Int, 3)
    }

    func testDecodeWithFallbackWithMissingKey() throws {
        let value = HAData(value: [])
        XCTAssertEqual(value.decode("name", fallback: 3) as Int, 3)
    }

    func testDecodeWithFallbackWithValue() throws {
        let value = HAData(value: ["name": "zacwest"])
        XCTAssertEqual(value.decode("name", fallback: "other") as String, "zacwest")
    }
}
