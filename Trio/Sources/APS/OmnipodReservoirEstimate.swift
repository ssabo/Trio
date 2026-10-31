import Foundation

/// Approximates the insulin left in an Omnipod while the pod only reports "50+ U".
///
/// A pod measures its reservoir only once 50 U or less remain. Above that, the amount left can be
/// approximated from what the user filled the pod with, minus everything the pod has dispensed since
/// activation (including the prime and cannula insertion boluses).
enum OmnipodReservoirEstimate {
    /// Pods report a measured reservoir level only at or below this amount.
    static let podMeasurementThreshold: Decimal = 50

    /// The approximate units remaining, rounded down to whole units, or nil when the pod's own
    /// reading should be shown instead.
    ///
    /// Returns nil when no fill amount is set, when the pod has not reported its delivery yet, when
    /// the pod has measured 50 U or less, and when the approximation is not above 50 U although the
    /// pod still reads 50+ U (the fill amount was set too low).
    ///
    /// - Parameters:
    ///   - fillAmount: Units the user filled the pod with, nil when no fill amount is set.
    ///   - podReservoirLevel: Reservoir level from the pod's last status, nil when not yet known.
    ///   - insulinDispensed: Units the pod has dispensed since activation, nil when not yet known.
    static func approximateUnitsRemaining(
        fillAmount: Decimal?,
        podReservoirLevel: Double?,
        insulinDispensed: Double?
    ) -> Decimal? {
        guard let fillAmount, let insulinDispensed else { return nil }

        // Once the pod measures its reservoir, its reading always wins.
        if let podReservoirLevel, Decimal(podReservoirLevel) <= podMeasurementThreshold {
            return nil
        }

        // Pod deliveries are in 0.05 U pulses: drop binary floating point noise before rounding down.
        var remaining = fillAmount - Decimal(insulinDispensed).rounded(toPlaces: 2)
        var wholeUnits = Decimal()
        NSDecimalRound(&wholeUnits, &remaining, 0, .down)

        guard wholeUnits > podMeasurementThreshold else { return nil }
        return wholeUnits
    }
}
