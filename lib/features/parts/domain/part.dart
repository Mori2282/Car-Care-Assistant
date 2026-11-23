class Part {
  const Part({
    required this.name,
    required this.brand,
    required this.number,
    required this.oe,
    required this.source,
    required this.fitmentConfirmed,
    this.fitmentVehicleId = '',
  });

  final String name;
  final String brand;
  final String number;
  final String oe;
  final String source;
  final bool fitmentConfirmed;
  final String fitmentVehicleId;

  bool fitsCatalogVehicle(String id) =>
      id.isNotEmpty && fitmentConfirmed && fitmentVehicleId == id;

  String get key =>
      '${brand.trim().toUpperCase()}|${normalizePartNumber(number)}|${normalizePartNumber(oe)}';

  Map<String, Object> toJson() => {
    'name': name,
    'brand': brand,
    'number': number,
    'oe': oe,
    'source': source,
    'fitmentConfirmed': fitmentConfirmed,
    'fitmentVehicleId': fitmentVehicleId,
  };

  factory Part.fromJson(Map<String, dynamic> json) {
    String read(String key) => (json[key] as String?)?.trim() ?? '';
    return Part(
      name: read('name'),
      brand: read('brand'),
      number: read('number'),
      oe: read('oe'),
      source: read('source'),
      fitmentConfirmed: json['fitmentConfirmed'] == true,
      fitmentVehicleId: read('fitmentVehicleId'),
    );
  }
}

String normalizePartNumber(String number) =>
    number.toUpperCase().replaceAll(RegExp(r'[\s./_-]'), '');
