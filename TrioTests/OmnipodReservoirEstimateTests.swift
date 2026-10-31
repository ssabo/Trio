import Foundation
import Testing

@testable import Trio

@Suite("Omnipod Reservoir Estimate Tests") struct OmnipodReservoirEstimateTests {
    /// What OmnipodKit stores as the reservoir level while the pod reads 50+ U.
    private let aboveThreshold = 51.15

    @Test("Approximates fill amount minus insulin dispensed while the pod reads 50+ U")
    func approximatesWhileAboveThreshold() {
        let estimate = OmnipodReservoirEstimate.approximateUnitsRemaining(
            fillAmount: 200,
            podReservoirLevel: aboveThreshold,
            insulinDispensed: 4.95
        )
        #expect(estimate == 195)
    }

    @Test("Rounds down to whole units")
    func roundsDown() {
        let estimate = OmnipodReservoirEstimate.approximateUnitsRemaining(
            fillAmount: 150,
            podReservoirLevel: aboveThreshold,
            insulinDispensed: 20.05
        )
        #expect(estimate == 129)
    }

    @Test("Floating point noise above a whole unit does not drop a unit")
    func wholeUnitsStayWhole() {
        // 30.000000000000004 would otherwise leave 69.999... and round down to 69
        let estimate = OmnipodReservoirEstimate.approximateUnitsRemaining(
            fillAmount: 100,
            podReservoirLevel: aboveThreshold,
            insulinDispensed: 30.0.nextUp
        )
        #expect(estimate == 70)
    }

    @Test("No approximation without a fill amount")
    func noFillAmount() {
        let estimate = OmnipodReservoirEstimate.approximateUnitsRemaining(
            fillAmount: nil,
            podReservoirLevel: aboveThreshold,
            insulinDispensed: 10
        )
        #expect(estimate == nil)
    }

    @Test("No approximation before the pod reports its delivery")
    func noDeliveryReported() {
        let estimate = OmnipodReservoirEstimate.approximateUnitsRemaining(
            fillAmount: 200,
            podReservoirLevel: nil,
            insulinDispensed: nil
        )
        #expect(estimate == nil)
    }

    @Test("The pod's measured reading wins at or below 50 U", arguments: [50.0, 49.95, 12.3, 0])
    func podMeasurementWins(level: Double) {
        let estimate = OmnipodReservoirEstimate.approximateUnitsRemaining(
            fillAmount: 200,
            podReservoirLevel: level,
            insulinDispensed: 10
        )
        #expect(estimate == nil)
    }

    @Test("Falls back to 50+ when the approximation contradicts the pod", arguments: [150.0, 160.0, 199.0])
    func contradictsPod(dispensed: Double) {
        // filled 200 U, so these leave 50 U or less, yet the pod still reads 50+ U
        let estimate = OmnipodReservoirEstimate.approximateUnitsRemaining(
            fillAmount: 200,
            podReservoirLevel: aboveThreshold,
            insulinDispensed: dispensed
        )
        #expect(estimate == nil)
    }

    @Test("Lowest approximation shown is 51 U")
    func lowestApproximation() {
        let estimate = OmnipodReservoirEstimate.approximateUnitsRemaining(
            fillAmount: 200,
            podReservoirLevel: aboveThreshold,
            insulinDispensed: 149
        )
        #expect(estimate == 51)
    }
}
