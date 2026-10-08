/// The voices offered on the board. Order here is the order in the UI.
public enum Preset: String, CaseIterable, Sendable {
    case clean
    case robot
    case radio
    case echo
    case cathedral
    case chipmunk
    case female
    case demon
    case alien

    public var index: Int {
        Self.allCases.firstIndex(of: self)!
    }
}
