/// User choices for cursor awareness and direct pointer interaction.
public struct InteractionSettings: Equatable, Sendable {
    public var cursorReactionsEnabled: Bool
    public var directInteractionEnabled: Bool

    public init(cursorReactionsEnabled: Bool = true, directInteractionEnabled: Bool = true) {
        self.cursorReactionsEnabled = cursorReactionsEnabled
        self.directInteractionEnabled = directInteractionEnabled
    }
}
