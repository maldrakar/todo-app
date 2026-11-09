import Testing
@testable import TodoAppleUI

/// What is typed while the field has the focus stands at once, and goes up.
@Test func whatIsTypedStandsAndGoesUp() {
    var field = TypedText("Buy")
    let goesUp = field.typed("Buy m", goesUp: true)
    #expect(goesUp)
    #expect(field.text == "Buy m")
}

/// A field writes back the text it holds, on Return among other times, which is no keystroke.
@Test func theTextItHoldsIsNoKeystroke() {
    var field = TypedText("Buy")
    let goesUp = field.typed("Buy", goesUp: true)
    #expect(!goesUp)
    #expect(field.text == "Buy")
}

/// A text written while the field has no focus stands in it and sends nothing, so it waits for no answer: the model's
/// own text of the same words later on is the module's and stands, and the one before it is no echo.
@Test func aTextNeverSentWaitsForNoAnswer() {
    var field = TypedText("")
    let goesUp = field.typed("a", goesUp: false)
    #expect(!goesUp)
    #expect(field.text == "a")
    _ = field.typed("ab", goesUp: true)
    field.modelHolds("a")
    #expect(field.text == "a", "\"a\" was never sent, so it is the module's own")
}

/// A model drawn before the last keystroke arrives after it, and takes no letter back: on an iPhone 17 at the speed a
/// test types, "Quick 0x" went back to "Quick 0" one time in five (the iOS 26.3 simulator, 2026-11-07).
@Test func aModelThatLagsTakesNoLetterBack() {
    var field = TypedText("")
    _ = field.typed("a", goesUp: true)
    _ = field.typed("ab", goesUp: true)
    field.modelHolds("a")
    #expect(field.text == "ab")
    field.modelHolds("ab")
    #expect(field.text == "ab")
}

/// What the module holds that nothing typed here sent stands in the field: the next subtask's empty field after Return,
/// a title the store kept trimmed, another device's change.
@Test func whatTheModuleHoldsOfItsOwnStands() {
    var field = TypedText("")
    _ = field.typed("a", goesUp: true)
    field.modelHolds("a")
    field.modelHolds("")
    #expect(field.text == "")
    field.modelHolds("From a peer")
    #expect(field.text == "From a peer")
}

/// Once the module answers with a text of its own, what was sent before it is no longer waited for, so typing that same
/// text again goes up, and the model coming back with it is an echo again.
@Test func anAnswerOfItsOwnForgetsWhatWasSent() {
    var field = TypedText("")
    _ = field.typed("a", goesUp: true)
    _ = field.typed("ab", goesUp: true)
    field.modelHolds("trimmed")
    #expect(field.text == "trimmed")
    let goesUp = field.typed("ab", goesUp: true)
    #expect(goesUp)
    _ = field.typed("abc", goesUp: true)
    field.modelHolds("ab")
    #expect(field.text == "abc", "an echo of what was typed again")
}

/// A text typed, cleared and typed again leaves an old entry behind that must not swallow a later answer: the model
/// coming back with the newest of them has seen all of them, so the empty text after it is the module's own.
@Test func anEchoForgetsEverythingSentBeforeIt() {
    var field = TypedText("")
    _ = field.typed("a", goesUp: true)
    _ = field.typed("", goesUp: true)
    _ = field.typed("a", goesUp: true)
    field.modelHolds("a")
    field.modelHolds("")
    #expect(field.text == "")
}

/// From an empty subtask's field, a letter and Return handled with no render between them take the model from "" to "a"
/// and back to "" (`TaskList.writeSubtask`): no change the view can see, so Return itself puts the field back on what
/// the model last showed.
@Test func aReturnWithNoRenderFallsBackOnTheModel() {
    var field = TypedText("")
    _ = field.typed("a", goesUp: true)
    field.settled()
    #expect(field.text == "")
    let goesUp = field.typed("b", goesUp: true)
    #expect(goesUp)
    field.modelHolds("b")
    #expect(field.text == "b")
}

/// Return or a lost focus with the model behind: the field falls back on what it last showed, and the model's change
/// that follows, the letter it had not drawn or the store's trimmed text, settles it.
@Test func aSettledFieldTakesTheModelsNextChange() {
    var field = TypedText("Buy mil")
    _ = field.typed("Buy milk", goesUp: true)
    field.settled()
    #expect(field.text == "Buy mil")
    field.modelHolds("Buy milk")
    #expect(field.text == "Buy milk")
}

/// A write refused after Return leaves the field its text: the model's next change brings it back.
@Test func aRefusedReturnLeavesTheFieldItsText() {
    var field = TypedText("")
    _ = field.typed("a", goesUp: true)
    field.settled()
    field.modelHolds("a")
    #expect(field.text == "a")
}
