// MonaMarkerServiceTest.swift
//
// Behavior test for MonaMarkerService (MODEL-008 / P05-T122).
//
// Verifies the marker service's set/get/remove storage and the
// `onDidChangeMarkers` change event. Also verifies the four retained public
// editor functions (`monaEditorSetModelMarkers`, `monaEditorRemoveAllMarkers`,
// `monaEditorGetModelMarkers`, `monaEditorOnDidChangeMarkers`) route through
// the shared singleton service.

import XCTest
import MonaCode

final class MonaMarkerServiceTest: XCTestCase {

    // MARK: - Service direct: set / get / remove + change event

    func testServiceSetGetRemoveAndChangeEventFires() async throws {
        let service = MonaMarkerService()
        let model = MonaCodeModel(
            text: "line1\nline2",
            uri: MonaURI(scheme: "inmemory", path: "/marker-service-test")
        )

        var received: [MonaMarkerChangeEvent] = []
        let disposable = service.onDidChangeMarkers { event in
            received.append(event)
        }
        defer { disposable.dispose() }

        let markers = [
            MonaMarker(severity: .error, message: "syntax error"),
            MonaMarker(severity: .warning, message: "unused var", tag: .unnecessary),
        ]

        // set
        service.setModelMarkers(markers, for: model, owner: "lint")

        // get returns exactly the set markers (single owner preserves order)
        let got = service.getModelMarkers(for: model)
        XCTAssertEqual(got.count, 2, "set markers should be retrievable")
        XCTAssertEqual(got[0].severity, .error)
        XCTAssertEqual(got[0].message, "syntax error")
        XCTAssertEqual(got[1].severity, .warning)
        XCTAssertEqual(got[1].tag, .unnecessary)

        // change event fired once, carrying the affected model id
        XCTAssertEqual(received.count, 1, "set should fire one change event")
        XCTAssertEqual(received[0].affectedModelIds, [model.id])

        // remove by owner
        service.removeAllMarkers(owner: "lint")
        XCTAssertEqual(service.getModelMarkers(for: model).count, 0, "remove by owner should clear markers")
        XCTAssertEqual(received.count, 2, "remove should fire a second change event")
        XCTAssertEqual(received[1].affectedModelIds, [model.id])
    }

    func testServiceSetReplacesPriorMarkersForSameOwner() async throws {
        let service = MonaMarkerService()
        let model = MonaCodeModel(
            text: "x",
            uri: MonaURI(scheme: "inmemory", path: "/marker-replace-test")
        )

        service.setModelMarkers(
            [MonaMarker(severity: .error, message: "first")],
            for: model,
            owner: "owner"
        )
        XCTAssertEqual(service.getModelMarkers(for: model).count, 1)

        // a second set for the same owner replaces, not appends
        service.setModelMarkers(
            [
                MonaMarker(severity: .info, message: "second-a"),
                MonaMarker(severity: .info, message: "second-b"),
            ],
            for: model,
            owner: "owner"
        )
        let got = service.getModelMarkers(for: model)
        XCTAssertEqual(got.count, 2, "second set should replace the first")
        XCTAssertEqual(got.first?.message, "second-a")
    }

    func testServiceRemoveAllWithoutOwnerClearsEverything() async throws {
        let service = MonaMarkerService()
        let modelA = MonaCodeModel(
            text: "a", uri: MonaURI(scheme: "inmemory", path: "/marker-rm-a"))
        let modelB = MonaCodeModel(
            text: "b", uri: MonaURI(scheme: "inmemory", path: "/marker-rm-b"))

        var fired = 0
        let disposable = service.onDidChangeMarkers { _ in fired += 1 }
        defer { disposable.dispose() }

        service.setModelMarkers(
            [MonaMarker(severity: .hint, message: "a")], for: modelA, owner: "o1")
        service.setModelMarkers(
            [MonaMarker(severity: .hint, message: "b")], for: modelB, owner: "o2")
        XCTAssertEqual(fired, 2)

        // remove all (no owner) clears every owner and model
        service.removeAllMarkers()
        XCTAssertEqual(service.getModelMarkers(for: modelA).count, 0)
        XCTAssertEqual(service.getModelMarkers(for: modelB).count, 0)
        XCTAssertEqual(fired, 3, "removeAll should fire one change event")
    }

    // MARK: - Public editor functions route through the shared service

    func testPublicFunctionsRouteThroughSharedService() async throws {
        let shared = MonaMarkerService.shared
        let model = MonaCodeModel(
            text: "public",
            uri: MonaURI(scheme: "inmemory", path: "/marker-public-route")
        )
        // Clean the shared singleton so this test is hermetic.
        defer { shared.removeAllMarkers() }

        var fired = 0
        let event = try await monaEditorOnDidChangeMarkers()
        let disposable = event { _ in fired += 1 }
        defer { disposable.dispose() }

        try await monaEditorSetModelMarkers(
            model: model,
            owner: "pubowner",
            markers: [MonaMarker(severity: .info, message: "info marker")]
        )
        let got = try await monaEditorGetModelMarkers(for: model)
        XCTAssertEqual(got.count, 1, "public set/get should route through the service")
        XCTAssertEqual(got.first?.message, "info marker")
        XCTAssertEqual(fired, 1, "public set should fire the change event via the service")

        try await monaEditorRemoveAllMarkers(owner: "pubowner")
        let afterRemove = try await monaEditorGetModelMarkers(for: model)
        XCTAssertEqual(
            afterRemove.count, 0,
            "public removeAll should route through the service"
        )
        XCTAssertEqual(fired, 2, "public removeAll should fire the change event via the service")
    }
}
