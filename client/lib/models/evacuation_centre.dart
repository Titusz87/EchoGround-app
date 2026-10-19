class EvacuationCentre {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String status;
  final int? capacity;
  final int? currentOccupancy;
  final String? phone;
  final bool? petsAllowed;
  final String? accessibility;
  final String? openingTime;
  final String? closingTime;
  final String? updatedAt;

  const EvacuationCentre({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.capacity,
    this.currentOccupancy,
    this.phone,
    this.petsAllowed,
    this.accessibility,
    this.openingTime,
    this.closingTime,
    this.updatedAt,
  });
}