//
//  EnFlowTests.swift
//  EnFlowTests
//
//  Created by Orion Goodman on 6/11/25.
//

import Testing
@testable import EnFlow

struct EnFlowTests {

    @Test func jsonFormatterPrettifiesSimpleJSON() throws {
        let raw = "{\"a\":1}"
        let pretty = JSONFormatter.pretty(from: raw)
        #expect(pretty.contains("\n"))
        #expect(pretty.contains("\"a\""))
    }

    @Test func jsonFormatterRemovesCodeFences() throws {
        let raw = "```json\n{\"a\":1}\n```"
        let pretty = JSONFormatter.pretty(from: raw)
        #expect(!pretty.contains("```"))
        #expect(pretty.contains("\"a\""))
    }

    @Test func weeklySummaryFormatterProducesBullets() throws {
        let raw = """
        sections:
          - title: "T"
            content: "C"
        events:
          - title: "E"
            date: "2025-06-25"
        """
        let text = WeeklySummaryFormatter.format(from: raw)
        #expect(text.contains("\u2022 T: C"))
        #expect(text.contains("E"))
    }

    @Test func weeklySummaryFormatterHandlesWrappedYAML() throws {
        let raw = "Here you go: ```yaml\nsections:\n  - title: \"A\"\n    content: \"B\"\nevents: []\n``` Enjoy!"
        let text = WeeklySummaryFormatter.format(from: raw)
        #expect(text.contains("\u2022 A: B"))
    }

    @Test func weeklySummaryFormatterFallsBackGracefully() throws {
        let raw = "not really yaml"
        let text = WeeklySummaryFormatter.format(from: raw)
        #expect(text.contains("not really yaml"))
    }

}
