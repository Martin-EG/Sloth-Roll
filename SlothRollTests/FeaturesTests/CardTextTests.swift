import Foundation
import Testing

@testable import SlothRoll

struct CardTextTests {
    @Test func eventWithoutDateSaysSo() {
        let result = ActionResult(
            type: .event, title: "Cena", location: "Casa", confidence: .high)

        #expect(CardText.proposal(result) == "Add event · no date · Casa")
    }

    @Test func placeShowsLocation() {
        let result = ActionResult(
            type: .place, title: "Teatro", location: "Xalapa", confidence: .high)

        #expect(CardText.proposal(result) == "Open in Maps · Xalapa")
    }

    @Test func receiptWithoutAmountSaysSo() {
        let result = ActionResult(type: .receipt, title: "OXXO", confidence: .high)

        #expect(CardText.proposal(result) == "Add expense · no amount")
    }
}
