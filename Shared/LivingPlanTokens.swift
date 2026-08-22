struct AdaptiveRGB {
    let light: UInt
    let dark: UInt

    init(light: UInt, dark: UInt) {
        self.light = light
        self.dark = dark
    }
}

/// Cross-target color values for the Living Plan Table visual system.
enum LivingPlanTokens {
    static let canvas = AdaptiveRGB(light: 0xEEF4F2, dark: 0x0C1513)
    static let recessed = AdaptiveRGB(light: 0xE0EBE7, dark: 0x12201D)
    static let raised = AdaptiveRGB(light: 0xFAFCFB, dark: 0x182823)
    static let ink = AdaptiveRGB(light: 0x15332E, dark: 0xF3F8F6)
    static let mutedInk = AdaptiveRGB(light: 0x58716B, dark: 0x9CB2AC)
    static let divider = AdaptiveRGB(light: 0xC9DAD5, dark: 0x2A423C)
    static let navigationMaterial = AdaptiveRGB(light: 0xE7F0ED, dark: 0x172923)
    static let navigationDeep = AdaptiveRGB(light: 0x15332E, dark: 0x09110F)
    static let navigationHighlight = AdaptiveRGB(light: 0xFFFFFF, dark: 0x254039)
    static let onNavigation = AdaptiveRGB(light: 0x15332E, dark: 0xF3F8F6)

    static let success = AdaptiveRGB(light: 0x2F7657, dark: 0x76CFA5)
    static let successFill = AdaptiveRGB(light: 0x3F936D, dark: 0x4DAE81)
    static let danger = AdaptiveRGB(light: 0xA64139, dark: 0xF28A80)
    static let dangerFill = AdaptiveRGB(light: 0xC75A50, dark: 0xD86C62)

    static let spruceAnnotation = AdaptiveRGB(light: 0x176B5B, dark: 0x68C7B0)
    static let spruceAction = AdaptiveRGB(light: 0x125447, dark: 0x8AD8C5)
    static let spruceFill = AdaptiveRGB(light: 0x1E7666, dark: 0x2A927E)
    static let clayAnnotation = AdaptiveRGB(light: 0x96513E, dark: 0xE9A08A)
    static let clayAction = AdaptiveRGB(light: 0x743D2F, dark: 0xF0B6A5)
    static let clayFill = AdaptiveRGB(light: 0xA95F49, dark: 0xC97C65)
    static let mossAnnotation = AdaptiveRGB(light: 0x557A43, dark: 0x9BCB82)
    static let mossAction = AdaptiveRGB(light: 0x3F5E32, dark: 0xB5DEA0)
    static let mossFill = AdaptiveRGB(light: 0x668E50, dark: 0x79A962)
    static let pencilBlueAnnotation = AdaptiveRGB(light: 0x356D85, dark: 0x7AB9D3)
    static let pencilBlueAction = AdaptiveRGB(light: 0x29566A, dark: 0xA0D0E2)
    static let pencilBlueFill = AdaptiveRGB(light: 0x477F97, dark: 0x5B9DB8)
    static let irisAnnotation = AdaptiveRGB(light: 0x66568E, dark: 0xB5A4DE)
    static let irisAction = AdaptiveRGB(light: 0x4D416D, dark: 0xCFC3EB)
    static let irisFill = AdaptiveRGB(light: 0x7868A2, dark: 0x9281BD)
}
