import QtQml

// Test stand-in for the PamResult enum: QML enums are read off the TYPE name
// (PamResult.Success), whatever the enum inside is called.
QtObject {
    enum Values {
        Success = 1,
        Error = 2,
        Failed = 3,
        MaxTries = 4
    }
}
