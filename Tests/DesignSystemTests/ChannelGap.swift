import DesignSystem

/// The largest gap between a channel of `got` and the same channel of `want`, in units of 1/255, the precision the
/// canvas writes a hex to: a colour the look derives is the canvas's when the gap is at most one.
func channelGap(_ got: DesignSystem.RGB, _ want: DesignSystem.RGB) -> Double {
    max(abs(got.red - want.red), abs(got.green - want.green), abs(got.blue - want.blue)) * 255
}
