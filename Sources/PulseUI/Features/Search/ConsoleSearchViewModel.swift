// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleSearchViewModel: ObservableObject {
    var isButtonResetEnabled: Bool { !isCriteriaDefault }

    @Published var criteria = ConsoleSearchCriteria()
    @Published var mode: ConsoleViewModel.Mode = .messages

    let labels: ManagedObjectsObserver<LoggerLabelEntity>
    let domains: ManagedObjectsObserver<NetworkDomainEntity>

    private(set) var defaultCriteria = ConsoleSearchCriteria()
    private let store: LoggerStore

    init(store: LoggerStore) {
        self.store = store

        self.labels = ManagedObjectsObserver(context: store.viewContext, sortDescriptior: NSSortDescriptor(keyPath: \LoggerLabelEntity.name, ascending: true))
        self.domains = ManagedObjectsObserver(context: store.viewContext, sortDescriptior: NSSortDescriptor(keyPath: \NetworkDomainEntity.count, ascending: false))

        if store.isArchive {
            criteria.shared.dates.startDate = nil
            criteria.shared.dates.endDate = nil
        }
        defaultCriteria = criteria
    }

    var isCriteriaDefault: Bool {
        guard criteria.shared == defaultCriteria.shared else { return false }
        switch mode {
        case .messages: return criteria.messages == defaultCriteria.messages
        case .network: return criteria.network == defaultCriteria.network
        }
    }

    func resetAll() {
        criteria = defaultCriteria
    }

    func removeAllPins() {
        store.pins.removeAllPins()

#if os(iOS)
        runHapticFeedback(.success)
        ToastView {
            HStack {
                Image(systemName: "trash")
                Text("All pins removed")
            }
        }.show()
#endif
    }

    // MARK: Binding (ConsoleFilters.LogLevel)

    func binding(forLevel level: LoggerStore.Level) -> Binding<Bool> {
        Binding(get: {
            self.criteria.messages.logLevels.levels.contains(level)
        }, set: { isOn in
            if isOn {
                self.criteria.messages.logLevels.levels.insert(level)
            } else {
                self.criteria.messages.logLevels.levels.remove(level)
            }
        })
    }

    /// Returns binding for toggling all log levels.
    var bindingForTogglingAllLevels: Binding<Bool> {
        Binding(get: {
            self.criteria.messages.logLevels.levels.count == LoggerStore.Level.allCases.count
        }, set: { isOn in
            if isOn {
                self.criteria.messages.logLevels.levels = Set(LoggerStore.Level.allCases)
            } else {
                self.criteria.messages.logLevels.levels = Set()
            }
        })
    }

    // MARK: Binding (ConsoleFilters.Labels)

    func binding(forLabel label: String) -> Binding<Bool> {
        Binding(get: {
            if let focused = self.criteria.messages.labels.focused {
                return label == focused
            } else {
                return !self.criteria.messages.labels.hidden.contains(label)
            }
        }, set: { isOn in
            self.criteria.messages.labels.focused = nil
            if isOn {
                self.criteria.messages.labels.hidden.remove(label)
            } else {
                self.criteria.messages.labels.hidden.insert(label)
            }
        })
    }

    var bindingForTogglingAllLabels: Binding<Bool> {
        Binding(get: {
            self.criteria.messages.labels.hidden.isEmpty
        }, set: { isOn in
            self.criteria.messages.labels.focused = nil
            if isOn {
                self.criteria.messages.labels.hidden = []
            } else {
                self.criteria.messages.labels.hidden = Set(self.labels.objects.map(\.name))
            }
        })
    }

    // MARK: Custom Filters

    func remove(_ filter: ConsoleCustomMessageFilter) {
        if let index = criteria.messages.custom.filters.firstIndex(where: { $0.id == filter.id }) {
            criteria.messages.custom.filters.remove(at: index)
        }
    }

    func remove(_ filter: ConsoleCustomNetworkFilter) {
        if let index = criteria.network.custom.filters.firstIndex(where: { $0.id == filter.id }) {
            criteria.network.custom.filters.remove(at: index)
        }
    }

    var programmaticFilters: [ConsoleCustomNetworkFilter]? {
        let programmaticFilters = criteria.network.custom.filters.filter { $0.isProgrammatic && !$0.value.isEmpty }
        guard !programmaticFilters.isEmpty && criteria.network.custom.isEnabled else {
            return nil
        }
        return programmaticFilters
    }

    // MARK: Bindings

    func binding(forDomain domain: String) -> Binding<Bool> {
        Binding(get: {
            !self.criteria.network.host.ignoredHosts.contains(domain)
        }, set: { newValue in
            if self.criteria.network.host.ignoredHosts.remove(domain) == nil {
                self.criteria.network.host.ignoredHosts.insert(domain)
            }
        })
    }
}