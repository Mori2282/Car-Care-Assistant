String normalizeVin(String value) => value
    .toUpperCase()
    .replaceFirst(RegExp(r'^\s*(?:VIN|FIN|FRAME)\s*:\s*'), '')
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll(RegExp('[‐‑‒–—−]'), '-');

final _vinPattern = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');
final _framePattern = RegExp(r'^[A-Z0-9]{2,12}-[0-9]{4,12}$');

bool isVin(String value) => _vinPattern.hasMatch(value);

bool isFrame(String value) =>
    _framePattern.hasMatch(value) &&
    RegExp('[A-Z]').hasMatch(value.split('-').first);

String? manufacturerId(String vin) =>
    !isVin(vin)
        ? null
        : vin[2] == '9'
        ? vin.substring(0, 3) + vin.substring(11, 14)
        : vin.substring(0, 3);
