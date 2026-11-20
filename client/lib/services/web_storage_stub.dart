/// No-op web storage fallback for non-web platforms.
void writeWebConfig(String key, String value) {}

/// No-op web storage reader for non-web platforms.
String? readWebConfig(String key) => null;
