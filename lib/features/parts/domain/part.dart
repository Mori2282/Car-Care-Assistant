class Part {
  const Part({
    required this.name,
    required this.brand,
    required this.number,
    required this.oe,
    required this.source,
    required this.fitmentConfirmed,
  });

  final String name;
  final String brand;
  final String number;
  final String oe;
  final String source;
  final bool fitmentConfirmed;

  String get key =>
      '${brand.trim().toUpperCase()}|${normalizePartNumber(number)}|${normalizePartNumber(oe)}';

  Map<String, Object> toJson() => {
    'name': name,
    'brand': brand,
    'number': number,
    'oe': oe,
    'source': source,
    'fitmentConfirmed': fitmentConfirmed,
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
    );
  }
}

String normalizePartNumber(String number) =>
    number.toUpperCase().replaceAll(RegExp(r'[\s./_-]'), '');
