import Foundation

class EventBus<EventName: Hashable> {
    typealias Listener = () -> Void
    typealias Unsubscriber = () -> Void

    private var registry: [EventName: Array<ListenerRef>] = [:]

    init() {}

    func listen(eventName: EventName, listener: @escaping Listener) -> Unsubscriber {
        let listenerRef = ListenerRef(listener: listener)
        DispatchQueue.main.async {
            var listeners = self.registry[eventName] ?? []
            listeners.append(listenerRef)
            self.registry[eventName] = listeners
        }

        return {
            DispatchQueue.main.async {
                var listeners = self.registry[eventName] ?? []
                listeners = listeners.filter { $0 !== listenerRef }
                self.registry[eventName] = listeners
            }
        }
    }

    func dispatch(eventName: EventName) {
        DispatchQueue.main.async {
            let listeners = self.registry[eventName] ?? []
            listeners.forEach {
                $0.listener()
            }
        }
    }

    private class ListenerRef {
        var listener: Listener

        init(listener: @escaping Listener) {
            self.listener = listener
        }
    }
}
