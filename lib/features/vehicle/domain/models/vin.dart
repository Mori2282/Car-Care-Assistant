String normalizeVin(String value) =>
    value.replaceAll(RegExp(r'\s+'), '').toUpperCase();

bool isVin(String value) => RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(value);
