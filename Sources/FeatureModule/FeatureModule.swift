// Sources/FeatureModule/FeatureModule.swift

/// Everything that reaches a module: what a view sent, and what the world did.
///
/// The static requirement is what lets a host lift an action into an event without knowing which module it
/// is holding, and it is why a view can be handed the one entrance and not the other: what a view gets is a
/// closure over `UserAction`, which cannot spell `.changed` or any other event of the world, because the
/// closure it was given does not take one (spec section 2).
public protocol FeatureEvent: Equatable, Sendable {
    associatedtype UserAction: Equatable & Sendable
    static func action(_ action: UserAction) -> Self
}

/// The logic of one screen, written once for every platform: it holds the state, answers every event with a
/// new model, and imports no UI framework (ADR-0006).
///
/// A class, because a module has a lifetime and a reference to the store, and everything beyond `model` is
/// its own. `send` is synchronous — when it returns, `model` is already the new one, which is what makes a
/// keystroke a round trip through the module rather than state a view keeps — and it never throws: an error
/// thrown outward would reach a view, which would then have to decide something. What the store refuses is
/// part of the model instead. `Output` is the one-shot fact the module cannot act on itself, which its
/// parent takes; a module that has nothing to ask for has `Never`.
public protocol FeatureModule: AnyObject {
    associatedtype Model: Equatable & Sendable
    associatedtype Event: FeatureEvent
    associatedtype Output: Equatable & Sendable

    var model: Model { get }
    func send(_ event: Event) -> Output?
}
