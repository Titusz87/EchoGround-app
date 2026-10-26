import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'database_helper.dart';

void initWebMessageListener() {
  web.window.onMessage.listen((web.MessageEvent event) async {
    final rawData = event.data;
    if (rawData == null) return;

    try {
      // 2. Call .dartify() directly as an extension method on the raw JS data object
      final dartData = rawData.dartify();

      // 3. Inspect it securely as a normal Dart dictionary
      if (dartData is Map) {
        if (dartData['type'] == 'INCIDENT_CLICK') {
          final dataPayload = dartData['data'];
          if (dataPayload != null && dataPayload is Map) {
            await DatabaseHelper.instance.insertNotification(
              Map<String, dynamic>.from(dataPayload),
            );
            print("Successfully captured background notification state into SQLite!");
          }
        }
      }
    } catch (e) {
      // Bypasses unrelated system browser messaging events smoothly
      print("Non-incident web event ignored: $e");
    }
  });
}

