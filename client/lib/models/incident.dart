class Incident {
  final int id;
  final String title;
  final String type;
  final String? severity;
  final double? latitude;
  final double? longitude;
  final String? startTime;
  final String? endTime;
  final String? status;

  const Incident({required this.id, required this.title, required this.type, this.severity, this.latitude, this.longitude, this.startTime, this.endTime, this.status});
}

