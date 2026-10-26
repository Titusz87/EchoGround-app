// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;
import 'database_helper.dart';

void initWebMessageListener() {
  // Use the specific native stream provider instead of a bracket string lookup
  web.window.onMessage.listen((web.MessageEvent event) async {
    final msgData = event.data;

    if (msgData is Map && msgData['type'] == 'INCIDENT_CLICK') {
      final dataPayload = msgData['data'];
      if (dataPayload != null) {
        await DatabaseHelper.instance.insertNotification(
          Map<String, dynamic>.from(dataPayload as Map),
        );
        print("Successfully captured background notification state into SQLite!");
      }
    }
  });
}
