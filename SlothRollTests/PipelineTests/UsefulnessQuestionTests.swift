import Testing

@testable import SlothRoll

struct UsefulnessQuestionTests {
    @Test(arguments: [
        ("yes", true), ("Yes.", true), ("YES!", true), ("Sí", true), ("Answer: yes", true),
        ("No.", false), ("no", false), ("No, it's a meme.", false),
    ])
    func readsYesAndNo(answer: String, expected: Bool) {
        #expect(UsefulnessQuestion.parse(answer) == expected)
    }

    @Test(arguments: ["", "maybe", "{\"type\":\"none\"}", "nothing", "not sure"])
    func anythingElseIsUnknown(answer: String) {
        #expect(UsefulnessQuestion.parse(answer) == nil)
    }
}
