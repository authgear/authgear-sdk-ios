import Foundation


typealias Unsubscriber = () -> Void

class Observable<T> {
    private let dispatchQueue: DispatchQueue
    private var value: T
    private var listeners: Array<ListenerContainer<T>> = Array()
    
    init(dispatchQueue: DispatchQueue, value: T) {
        self.dispatchQueue = dispatchQueue
        self.value = value
    }
    
    public func postValue(newValue: T) {
        dispatchQueue.async {
            self.value = newValue
            self.listeners.forEach { listener in
                listener.fn(self.value)
            }
        }
    }
    
    public func subscribe(_ listener: @escaping (T) -> Void) -> Unsubscriber {
        let container = ListenerContainer(fn: listener)
        dispatchQueue.async {
            listener(self.value)
            self.listeners.append(container)
        }
        return { [weak self] () in
            guard let this = self else { return }
            this.dispatchQueue.async {
                this.listeners = this.listeners.filter { thiscontainer in
                    return thiscontainer !== container
                }
            }
        }
    }
}

private class ListenerContainer<T> {
    let fn: (T) -> Void
    
    init(fn: @escaping (T) -> Void) {
        self.fn = fn
    }
}
