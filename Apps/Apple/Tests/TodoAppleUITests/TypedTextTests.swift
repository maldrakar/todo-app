import Testing
@testable import TodoAppleUI

/// What is typed stands at once, and is what goes up.
@Test func whatIsTypedStandsAndGoesUp() {
    var field = TypedText("Buy")
    let isKeystroke = field.typed("Buy m")
    #expect(isKeystroke)
    #expect(field.text == "Buy m")
}

/// A field writes back the text it holds, on Return among other times, which is no keystroke.
@Test func theTextItHoldsIsNoKeystroke() {
    var field = TypedText("Buy")
    let isKeystroke = field.typed("Buy")
    #expect(!isKeystroke)
    #expect(field.text == "Buy")
}

/// A model drawn before the last keystroke arrives after it, and takes no letter back: on an iPhone 17 at the speed a
/// test types, "Quick 0x" went back to "Quick 0" one time in five (the iOS 26.3 simulator, 2026-11-07).
@Test func aModelThatLagsTakesNoLetterBack() {
    var field = TypedText("")
    _ = field.typed("a")
    _ = field.typed("ab")
    field.modelHolds("a")
    #expect(field.text == "ab")
    field.modelHolds("ab")
    #expect(field.text == "ab")
}

/// What the module holds that nothing typed here sent stands in the field: the next subtask's empty field after Return,
/// a title the store kept trimmed, another device's change.
@Test func whatTheModuleHoldsOfItsOwnStands() {
    var field = TypedText("")
    _ = field.typed("a")
    field.modelHolds("a")
    field.modelHolds("")
    #expect(field.text == "")
    field.modelHolds("From a peer")
    #expect(field.text == "From a peer")
}

/// Once the module answers with a text of its own, what was sent before it is no longer waited for, so typing that same
/// text again goes up and a later model of it is an echo again.
@Test func anAnswerOfItsOwnForgetsWhatWasSent() {
    var field = TypedText("")
    _ = field.typed("a")
    _ = field.typed("ab")
    field.modelHolds("trimmed")
    #expect(field.text == "trimmed")
    field.modelHolds("a")
    #expect(field.text == "a")
}
