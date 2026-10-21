import Foundation
import Testing

@testable import SlothRoll

struct ResultParserTests {
    private let parser = ResultParser()

    private let validJSON = """
        {"type":"receipt","title":"Oxxo","date":"2026-10-18","time":"19:42",\
        "location":"Oxxo Insurgentes","amount":249.50,"currency":"MXN","confidence":"high"}
        """

    @Test func decodesValidJSON() throws {
        let result = try parser.parse(validJSON)

        #expect(
            result
                == ActionResult(
                    type: .receipt, title: "Oxxo", date: "2026-10-18", time: "19:42",
                    location: "Oxxo Insurgentes", amount: Decimal(string: "249.50"),
                    currency: .mxn, confidence: .high))
    }

    @Test func stripsSurroundingProse() throws {
        let result = try parser.parse("Sure! Here is the JSON:\n\(validJSON)\nHope this helps.")
        #expect(result.type == .receipt)
        #expect(result.title == "Oxxo")
    }

    @Test func stripsMarkdownCodeFence() throws {
        let result = try parser.parse("```json\n\(validJSON)\n```")
        #expect(result.amount == Decimal(string: "249.50"))
    }

    @Test func toleratesTrailingCommas() throws {
        let result = try parser.parse(
            #"{"type":"place","title":"Café Avellaneda","location":"Coyoacán","confidence":"medium",}"#)
        #expect(result.type == .place)
        #expect(result.location == "Coyoacán")
        #expect(result.date == nil)
    }

    @Test func ignoresGarbageAfterObject() throws {
        let result = try parser.parse(validJSON + "}} <|im_end|> {oops")
        #expect(result.title == "Oxxo")
    }

    @Test func unknownTypeBecomesNone() throws {
        let result = try parser.parse(#"{"type":"reminder","title":"Call mom","confidence":"high"}"#)
        #expect(result.type == ActionType.none)
    }

    @Test func unknownConfidenceBecomesLow() throws {
        let result = try parser.parse(#"{"type":"event","title":"Cita","confidence":"very sure"}"#)
        #expect(result.confidence == .low)
    }

    @Test func spanishTypeAndLooseCurrencyAreAccepted() throws {
        let result = try parser.parse(
            #"{"type":"Recibo","title":"Uber","amount":"$1,249.50","currency":"mxn","confidence":"HIGH"}"#)
        #expect(result.type == .receipt)
        #expect(result.amount == Decimal(string: "1249.50"))
        #expect(result.currency == .mxn)
        #expect(result.confidence == .high)
    }

    @Test func unknownCurrencyBecomesNil() throws {
        let result = try parser.parse(#"{"type":"receipt","title":"Taxi","amount":20,"currency":"EUR","confidence":"low"}"#)
        #expect(result.currency == nil)
    }

    @Test func emptyAndNullWordsBecomeNil() throws {
        let result = try parser.parse(
            #"{"type":"none","title":"","date":"","time":"null","location":"N/A","confidence":"low"}"#)
        #expect(result.date == nil)
        #expect(result.time == nil)
        #expect(result.location == nil)
    }

    @Test func rejectsImpossibleDate() {
        #expect(throws: PipelineError.invalidDate("2026-02-30")) {
            try parser.parse(#"{"type":"event","title":"Boda","date":"2026-02-30","confidence":"high"}"#)
        }
    }

    @Test func rejectsWrongDateFormat() {
        #expect(throws: PipelineError.invalidDate("24/10/2026")) {
            try parser.parse(#"{"type":"event","title":"Boda","date":"24/10/2026","confidence":"high"}"#)
        }
    }

    @Test func rejectsInvalidTime() {
        #expect(throws: PipelineError.invalidTime("25:10")) {
            try parser.parse(#"{"type":"event","title":"Cena","time":"25:10","confidence":"high"}"#)
        }
    }

    @Test func padsOneDigitHour() throws {
        let result = try parser.parse(#"{"type":"event","title":"Cena","time":"9:30","confidence":"high"}"#)
        #expect(result.time == "09:30")
    }

    @Test func rejectsNegativeAmount() {
        #expect(throws: PipelineError.negativeAmount(-50)) {
            try parser.parse(#"{"type":"receipt","title":"Refund","amount":-50,"confidence":"high"}"#)
        }
    }

    @Test func rejectsTextWithoutJSON() {
        #expect(throws: PipelineError.noJSONObject) {
            try parser.parse("This screenshot shows a cat.")
        }
    }

    @Test func rejectsBrokenJSON() {
        #expect(throws: (any Error).self) {
            try parser.parse(#"{"type": "event", "title": }"#)
        }
    }

    @Test func rejectsObjectWithoutType() {
        #expect(throws: PipelineError.missingType) {
            try parser.parse(#"{"error": "The provided text does not contain a valid date."}"#)
        }
        #expect(throws: PipelineError.missingType) {
            try parser.parse(#"{"title": "Anuar 50's", "date": "2026-10-23", "confidence": "high"}"#)
        }
    }

    @Test func rejectsActionWithoutTitle() {
        #expect(throws: PipelineError.missingTitle) {
            try parser.parse(#"{"type":"event","date":"2026-10-24","confidence":"high"}"#)
        }
    }

    @Test func encodesEveryKeyWithNulls() throws {
        let data = try JSONEncoder().encode(Extractor.fallbackResult)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["type", "title", "date", "time", "location", "amount", "currency", "confidence"])
        #expect(object["date"] is NSNull)
    }
}
