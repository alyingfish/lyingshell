import QtQml

// Test stand-in for Quickshell's Singleton root under plain qml6. The real
// one accepts child objects (timers, contexts, handlers), so the mock needs
// the default property QtObject alone does not provide here.
QtObject {
    default property list<QtObject> data
}
