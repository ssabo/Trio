import Foundation
import LoopKit
import LoopKitUI
import SwiftDate
import SwiftUI

extension PumpConfig {
    final class StateModel: BaseStateModel<Provider> {
        @Published var setupPump = false
        private(set) var setupPumpEntry: PumpCatalogEntry?
        @Published var pumpState: PumpDisplayState?
        @Published var isOmnipodConnected = false
        @Published var useOmnipodReservoirFillAmount = false
        @Published var omnipodReservoirFillAmount: Decimal = 200
        @Published var units: GlucoseUnits = .mgdL
        private(set) var initialSettings: PumpInitialSettings = .default
        @Injected() var bluetoothManager: BluetoothStateManager!
        @Injected() var logExport: LogExport!

        override func subscribe() {
            units = settingsManager.settings.units
            subscribeSetting(\.useOmnipodReservoirFillAmount, on: $useOmnipodReservoirFillAmount) {
                useOmnipodReservoirFillAmount = $0 }
            subscribeSetting(\.omnipodReservoirFillAmount, on: $omnipodReservoirFillAmount) {
                omnipodReservoirFillAmount = $0 }

            provider.pumpDisplayState
                .receive(on: DispatchQueue.main)
                .sink { [weak self] pumpState in
                    guard let self = self else { return }
                    self.pumpState = pumpState
                    self.isOmnipodConnected = pumpState != nil && self.provider.isOmnipodConnected
                }
                .store(in: &lifetime)
            Task {
                let basalSchedule = BasalRateSchedule(
                    dailyItems: await provider.getBasalProfile().map {
                        RepeatingScheduleValue(startTime: $0.minutes.minutes.timeInterval, value: Double($0.rate))
                    }
                )

                let pumpSettings = provider.pumpSettings()

                await MainActor.run {
                    initialSettings = PumpInitialSettings(
                        maxBolusUnits: Double(pumpSettings.maxBolus),
                        maxBasalRateUnitsPerHour: Double(pumpSettings.maxBasal),
                        basalSchedule: basalSchedule!
                    )
                }
            }
        }

        func addPump(_ entry: PumpCatalogEntry) {
            setupPumpEntry = entry
            setupPump = true
        }
    }
}

extension PumpConfig.StateModel: CompletionDelegate {
    func completionNotifyingDidComplete(_: CompletionNotifying) {
        setupPump = false
    }
}

extension PumpConfig.StateModel: PumpManagerOnboardingDelegate {
    func pumpManagerOnboarding(didCreatePumpManager pumpManager: PumpManagerUI) {
        provider.setPumpManager(pumpManager)
        if let insulinType = pumpManager.status.insulinType {
            settingsManager.updateInsulinCurve(insulinType)
        }
    }

    func pumpManagerOnboarding(didOnboardPumpManager _: PumpManagerUI) {
        // nothing to do
    }

    func pumpManagerOnboarding(didPauseOnboarding _: PumpManagerUI) {
        // TODO:
    }
}
