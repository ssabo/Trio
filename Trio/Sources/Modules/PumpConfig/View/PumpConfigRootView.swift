import SwiftUI
import Swinject

extension PumpConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        let displayClose: Bool
        let bluetoothManager: BluetoothStateManager
        @StateObject var state = StateModel()
        @State private var shouldDisplayHint: Bool = false
        @State var hintDetent = PresentationDetent.large
        @State var selectedVerboseHint: AnyView?
        @State var hintLabel: String?
        @State private var decimalPlaceholder: Decimal = 0.0
        @State private var booleanPlaceholder: Bool = false
        @State var showPumpSelection: Bool = false
        @State private var shouldDisplaySettingHint: Bool = false
        @State private var pendingPump: PumpCatalogEntry?

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                Section(
                    header: Text("Pump Integration to Trio"),
                    content: {
                        if bluetoothManager.bluetoothAuthorization != .authorized {
                            HStack {
                                Spacer()
                                BluetoothRequiredView()
                                Spacer()
                            }
                        } else if let pumpState = state.pumpState {
                            Button {
                                state.setupPump = true
                            } label: {
                                HStack {
                                    Image(uiImage: pumpState.image ?? UIImage())
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 100)
                                    Text(pumpState.name)
                                }
                                .frame(maxWidth: .infinity, minHeight: 50, alignment: .center)
                                .font(.title2)
                            }.padding()
                        } else {
                            VStack {
                                Button {
                                    showPumpSelection.toggle()
                                } label: {
                                    Text("Add Pump")
                                        .font(.title3) }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .buttonStyle(.bordered)

                                HStack(alignment: .center) {
                                    Text(
                                        "Pair your insulin pump with Trio. See hint for compatible devices."
                                    )
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    Button(
                                        action: {
                                            shouldDisplayHint.toggle()
                                        },
                                        label: {
                                            HStack {
                                                Image(systemName: "questionmark.circle")
                                                    .accessibilityLabel(Text("More information"))
                                            }
                                        }
                                    ).buttonStyle(BorderlessButtonStyle())
                                }.padding(.top)
                            }.padding(.vertical)
                        }
                    }
                ).listRowBackground(Color.chart)

                if state.isOmnipodConnected {
                    SettingInputSection(
                        decimalValue: $state.omnipodReservoirFillAmount,
                        booleanValue: $state.useOmnipodReservoirFillAmount,
                        shouldDisplayHint: $shouldDisplaySettingHint,
                        selectedVerboseHint: Binding(
                            get: { selectedVerboseHint },
                            set: {
                                selectedVerboseHint = $0.map { AnyView($0) }
                                hintLabel = String(localized: "Approximate Reservoir")
                            }
                        ),
                        units: state.units,
                        type: .conditionalDecimal("omnipodReservoirFillAmount"),
                        label: String(localized: "Approximate Reservoir"),
                        conditionalLabel: String(localized: "Pod Fill Amount"),
                        miniHint: String(localized: "Show an approximate amount instead of 50+ U."),
                        verboseHint: VStack(alignment: .leading, spacing: 10) {
                            Text("Default: OFF").bold()
                            Text("Default Fill Amount: 200 U").bold()
                            Text(
                                "A pod only measures its reservoir once 50 U or less remain. Until then, it reports 50+ U."
                            )
                            Text(
                                "When enabled, Trio subtracts the insulin the pod has used since activation, including priming and cannula insertion, from your fill amount. The home screen then shows the result with a tilde, for example ~145 U."
                            )
                            Text(
                                "Once the pod measures 50 U or less, Trio always shows the pod's own reading."
                            )
                            Text(
                                "Set this to the amount you fill each new pod with. The approximation is only as accurate as that amount. It is for display only: dosing, alerts and Nightscout still use the pod's reading."
                            )
                        }
                    )
                }

                if state.pumpState != nil, state.provider?.apsManager?.pumpManager != nil {
                    Section {
                        LogShareRow(
                            title: "Share Pump Logs",
                            footnote: "Creates one file you can send when asking for help.",
                            kinds: [.pump],
                            logExport: state.logExport
                        )
                    }.listRowBackground(Color.chart)
                }
            }
            .scrollContentBackground(.hidden).background(appState.trioBackgroundColor(for: colorScheme))
            .onAppear(perform: configureView)
            .navigationBarTitleDisplayMode(.automatic)
            .navigationTitle("Insulin Pump")
            .settingsHighlightScroll()
            .sheet(isPresented: $state.setupPump) {
                if let pumpManager = state.provider.apsManager.pumpManager {
                    PumpSettingsView(
                        pumpManager: pumpManager,
                        bluetoothManager: state.provider.apsManager.bluetoothManager!,
                        completionDelegate: state,
                        setupDelegate: state
                    )
                } else if let pumpEntry = state.setupPumpEntry {
                    PumpSetupView(
                        pumpEntry: pumpEntry,
                        pumpInitialSettings: state.initialSettings,
                        bluetoothManager: state.provider.apsManager.bluetoothManager!,
                        completionDelegate: state,
                        setupDelegate: state
                    )
                }
            }
            .sheet(isPresented: $shouldDisplaySettingHint) {
                SettingInputHintView(
                    hintDetent: $hintDetent,
                    shouldDisplayHint: $shouldDisplaySettingHint,
                    hintLabel: hintLabel ?? "",
                    hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                    sheetTitle: String(localized: "Help", comment: "Help sheet title")
                )
            }
            .sheet(isPresented: $shouldDisplayHint) {
                SettingInputHintView(
                    hintDetent: $hintDetent,
                    shouldDisplayHint: $shouldDisplayHint,
                    hintLabel: "Pump Pairing to Trio",
                    hintText: AnyView(
                        VStack(alignment: .leading, spacing: 10) {
                            Text(
                                "Current Pump Models Supported:"
                            )
                            VStack(alignment: .leading) {
                                ForEach(DeviceCatalog.pumps) { pump in
                                    Text("• \(pump.hintLine)")
                                }
                            }
                            Text(
                                "Note: If using a pump simulator, you will not have continuous readings from the CGM in Trio. Using a pump simulator is only advisable for becoming familiar with the app user interface. It will not give you insight on how the algorithm will respond."
                            )
                        }
                    ),
                    sheetTitle: String(localized: "Help", comment: "Help sheet title")
                )
            }
            // Selection is applied in onDismiss so the setup sheet is presented only once the picker is gone.
            .sheet(isPresented: $showPumpSelection, onDismiss: {
                if let entry = pendingPump {
                    pendingPump = nil
                    state.addPump(entry)
                }
            }) {
                DevicePickerView(
                    title: String(localized: "Add Pump", comment: "The title of the pump chooser in settings"),
                    entries: DeviceCatalog.pumps
                ) { entry in
                    pendingPump = entry
                    showPumpSelection = false
                }
            }
        }
    }
}
