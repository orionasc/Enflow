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


    @Test func classifierIdentifiesShortWalkAsBooster() throws {
        let start = Date()
        let end = start.addingTimeInterval(900) // 15 min
        let event = CalendarEvent(eventTitle: "Afternoon Walk", startTime: start, endTime: end, isAllDay: false)
        let result = CalendarEventClassifier().classify(event)
        #expect(result.label == "Booster")
        #expect(result.confidence > 0.7)
    }

    @Test func classifierIdentifiesLongAfternoonMeetingAsDrainer() throws {
        let cal = Calendar.current
        var comps = DateComponents(); comps.hour = 14
        let start = cal.date(from: comps) ?? Date()
        let end = start.addingTimeInterval(7200) // 2 h
        let event = CalendarEvent(eventTitle: "Team Meeting", startTime: start, endTime: end, isAllDay: false)
        let result = CalendarEventClassifier().classify(event)
        #expect(result.label == "Drainer")
        #expect(result.confidence >= 0.8)
    }
}
