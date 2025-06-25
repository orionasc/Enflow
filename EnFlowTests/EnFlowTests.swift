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

}
