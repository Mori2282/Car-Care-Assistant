import 'package:car_care_app/core/catalog/catalog_api.dart';
import 'package:car_care_app/features/parts/data/parts_repository.dart';
import 'package:car_care_app/features/vehicle/data/datasources/nhtsa_api_service.dart';
import 'package:car_care_app/features/vehicle/domain/models/vehicle.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Dio respond(Object? Function(RequestOptions) response) =>
    Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: response(request),
              ),
            );
          },
        ),
      );

void main() {
  const vin = 'TMBJJ7NE1J0123456';
  test(
    'international catalog returns candidates and sends VIN in the request body',
    () async {
      final catalog = CatalogApi(
        baseUrl: 'https://example.test/api',
        dio: respond((request) {
          expect(request.uri.path, '/api/vin');
          expect(request.uri.hasQuery, isFalse);
          expect(request.data, {'vin': vin});
          return {
            'results': [
              {
                'brand': 'Škoda',
                'model': 'Octavia',
                'year': 2018,
                'variant': '1.6 TDI',
                'id': 'c42',
              },
            ],
          };
        }),
      );
      final result = await VinLookup(catalog).find(vin);
      expect(result.single.catalogId, 'c42');
      expect(result.single.variant, '1.6 TDI');
    },
  );

  test('vPIC partial result never invents a model or year', () async {
    final decoder = VinLookup(
      CatalogApi(baseUrl: ''),
      dio: respond(
        (_) => {
          'Results': [
            {'Make': 'Skoda', 'ModelYear': ''},
          ],
        },
      ),
    );
    final result = (await decoder.find(vin)).single;
    expect(result.brand, 'Skoda');
    expect(result.model, isEmpty);
    expect(result.year, isNull);
  });

  test(
    'catalog confirms fitment only for the exact catalog vehicle ID',
    () async {
      const car = Vehicle(
        id: 'local',
        brand: 'Skoda',
        model: 'Octavia',
        mileage: 0,
        vin: vin,
        year: 2018,
        catalogId: 'c42',
      );
      final catalog = CatalogApi(
        baseUrl: 'https://example.test',
        dio: respond((request) {
          expect((request.data as Map).containsKey('vin'), isFalse);
          return {
            'results': [
              {
                'brand': 'MANN',
                'number': 'A-12',
                'oe': 'X01',
                'vehicleId': 'c43',
                'fitmentConfirmed': true,
              },
              {
                'brand': 'MANN',
                'number': 'A12',
                'oe': 'X01',
                'vehicleId': 'c42',
                'fitmentConfirmed': true,
              },
              {
                'brand': 'Bosch',
                'number': 'B14',
                'oe': 'X01',
                'vehicleId': 'c43',
                'fitmentConfirmed': true,
              },
            ],
          };
        }),
      );
      final matches = await PartsRepository(catalog).search(car, 'X01');
      expect(matches, hasLength(2));
      expect(matches.first.fitmentConfirmed, isTrue);
      expect(matches.last.fitmentConfirmed, isFalse);
    },
  );
}
