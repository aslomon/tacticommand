import Foundation

/// A fully resolved key appearance, independent of wire encoding. The same value feeds both
/// the on-screen key presentation and the hardware payload builder.
public struct LightingKeyAppearance: Equatable, Sendable {
    public let color: RGBColor
    public let brightness: Double
    public let effect: LightingEffect
    public let speed: Double

    public init(color: RGBColor, brightness: Double, effect: LightingEffect, speed: Double) {
        self.color = color
        self.brightness = brightness
        self.effect = effect
        self.speed = speed
    }
}

/// Picks the single appearance tier that wins for one key, per the approved state priority:
/// failure > observed audio/dictation signal > agent status (caller only passes this when the
/// Agent Focus layer is active) > resting function-category color > unassigned (nil = dim/off).
/// Callers own building each tier's appearance; this type only orders them.
public enum LightingPriorityResolver {
    public static func resolve(
        failure: LightingKeyAppearance?,
        observedSignal: LightingKeyAppearance?,
        agentStatus: LightingKeyAppearance?,
        category: FunctionCategory?,
        isPressed: Bool
    ) -> LightingKeyAppearance? {
        if let failure { return failure }
        if let signal = observedSignal ?? agentStatus {
            return LightingKeyAppearance(
                color: signal.color, brightness: isPressed ? 1 : signal.brightness,
                effect: signal.effect, speed: signal.speed)
        }
        guard let category else { return nil }
        return LightingKeyAppearance(
            color: SemanticLightingPalette.color(for: category),
            brightness: isPressed
                ? SemanticLightingPalette.pressBrightness : SemanticLightingPalette.idleBrightness,
            effect: .solid,
            speed: 0
        )
    }
}
