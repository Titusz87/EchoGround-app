import 'dart:js_interop';

@JS('window.localStorage')
external _BrowserStorage get _localStorage;

extension type _BrowserStorage(JSObject _) implements JSObject {
  external void setItem(String key, String value);
  external String? getItem(String key);
}

/// Persists a configuration key-value pair in browser localStorage.
void writeWebConfig(String key, String value) {
  try {
    _localStorage.setItem('echoground_$key', value);
  } catch (_) {}
}

/// Reads a persisted configuration value from browser localStorage.
String? readWebConfig(String key) {
  try {
    return _localStorage.getItem('echoground_$key');
  } catch (_) {
    return null;
  }
}
