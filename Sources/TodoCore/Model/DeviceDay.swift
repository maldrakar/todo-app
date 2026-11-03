/// The device's calendar day and the instant it began, in the clock's milliseconds: the platform's reading,
/// which reaches a module as an event of the world and the core as an argument (ADR-0006, amendment of 2026-11-01).
///
/// The core has no time zone (ADR-0001), so it cannot tell which day it is on a device: the platform, which has one,
/// reads both values and hands them in together, so that they are one reading and never two that disagree. `day` is
/// what a query takes as `today`; `began` is the same day's start on the clock the store stamps its writes with, for
/// a read that asks what happened since the day began. Equatable, so that a module told the day it already has knows
/// it at one comparison and reads nothing.
public struct DeviceDay: Equatable, Sendable {
    /// The device's calendar day, as its calendar and time zone place the instant it was read.
    public let day: Day

    /// The instant `day` began on the device, in milliseconds since the epoch, the scale `Store.systemNow()` reads.
    public let began: Int64

    public init(day: Day, began: Int64) {
        self.day = day
        self.began = began
    }
}
