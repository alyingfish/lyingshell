import QtQml

// Test stand-in for the PamError enum, shaped like PamResult.
QtObject {
    enum Values {
        ConnectionFailed = 1,
        TryAgain = 2,
        InternalError = 3
    }
}
