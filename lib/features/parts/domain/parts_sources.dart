import '../../vehicle/domain/models/vehicle.dart';
import '../../vehicle/domain/models/vin.dart';

typedef PartsSource = ({String name, String detail, Uri uri});

List<PartsSource> partsSources(Vehicle vehicle, String query) {
  final brand = vehicle.brand.toLowerCase().replaceAll(
    RegExp(r'[^a-zа-я]'),
    '',
  );
  final chevrolet = ['chevrolet', 'chevy', 'шевроле'].contains(brand);
  final mercedes = brand.startsWith('mercedes') || brand.startsWith('мерседес');
  return [
    if (vehicle.market == 'JP' || isFrame(normalizeVin(vehicle.vin)))
      (
        name: 'Японские схемы и артикулы',
        detail: 'В PartSouq можно искать по номеру кузова или VIN.',
        uri: Uri.https('partsouq.com', '/en/catalogs/'),
      ),
    if (chevrolet)
      (
        name: 'Оригинальные детали Chevrolet',
        detail: 'Каталог GM для рынка США. Можно указать VIN на сайте.',
        uri: Uri.https('parts.chevrolet.com'),
      ),
    if (mercedes)
      (
        name: 'Схемы и артикулы Mercedes-Benz',
        detail:
            'Справочник 7zap. Выберите поколение и двигатель или проверьте VIN на сайте.',
        uri: Uri.https('7zap.com', '/en/catalog/cars/mercedes/'),
      ),
    if (vehicle.market == 'CN' ||
        [
          'byd',
          'chery',
          'geely',
          'haval',
          'changan',
          'gac',
          'jac',
          'jetour',
          'exeed',
          'zeekr',
          'tank',
          'greatwall',
          'omoda',
        ].contains(brand))
      (
        name: 'TecAlliance China',
        detail: 'Справочник для машин китайского рынка.',
        uri: Uri.https('www.tecalliance.cn'),
      ),
    (
      name: 'Поиск в интернете',
      detail: 'По модели, году и детали. Совместимость нужно проверить.',
      uri: Uri.https('www.google.com', '/search', {
        'q': [
          query,
          vehicle.brand,
          vehicle.model,
          vehicle.year.toString(),
          vehicle.variant,
          'запчасть',
        ].where((value) => value.isNotEmpty).join(' '),
      }),
    ),
  ];
}
