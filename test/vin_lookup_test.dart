import 'package:car_care_app/core/catalog/catalog_api.dart';
import 'package:car_care_app/features/vehicle/data/datasources/nhtsa_api_service.dart';
import 'package:car_care_app/features/vehicle/domain/models/vin.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_test.dart' show respond;

void main() {
  const mercedes = 'WDB2110061A000000';
  const frame = 'ZVW30-1234567';
  const skoda = 'TMBJJ7NE1J0123456';

  test(
    'normalizes pasted labels and FRAME without stripping meaningful separators',
    () {
      expect(normalizeVin(' frame: zvw30– 1234567 '), frame);
      expect(isFrame(frame), isTrue);
      expect(isVin(frame), isFalse);
      expect(isFrame('1234-567890'), isFalse);
      expect(manufacturerId(mercedes), 'WDB');
      expect(manufacturerId('WDB'), isNull);
      expect(manufacturerId('AB9XY12341A456789'), 'AB9456');
    },
  );

  for (final (prefix, make) in [
    ('WDB', 'MERCEDES-BENZ'),
    ('WBA', 'BMW'),
    ('WAU', 'AUDI'),
    ('WVW', 'VOLKSWAGEN'),
    ('WP0', 'PORSCHE'),
  ]) {
    test(
      'uses the same WMI fallback for $make without guessing a model or year',
      () async {
        final vin = '${prefix}1234561A000000';
        final service = VinLookup(
          CatalogApi(baseUrl: ''),
          dio: respond(
            (request) => {
              'Results': [
                if (request.uri.path.endsWith('/DecodeWMI/$prefix'))
                  {'Make': make}
                else
                  {
                    'Model': 'Uncertain',
                    'ModelYear': '2001',
                    'ErrorCode': '1,5,14',
                  },
              ],
            },
          ),
        );
        final match = (await service.find(vin)).single;
        expect(match.brand, make);
        expect(match.model, isEmpty);
        expect(match.year, isNull);
        expect(match.catalogId, isEmpty);
      },
    );
  }
  test(
    'a clean public VIN result offers a year, never a catalog fitment ID',
    () async {
      final service = VinLookup(
        CatalogApi(baseUrl: ''),
        dio: respond(
          (_) => {
            'Results': [
              {
                'Make': 'Mercedes-Benz',
                'Model': 'E-Class',
                'ModelYear': '2007',
                'ErrorCode': '0',
              },
            ],
          },
        ),
      );
      final match = (await service.find('WDBUF56J67B000000')).single;
      expect(match.year, 2007);
      expect(match.catalogId, isEmpty);
    },
  );

  test(
    'conflicting VIN fields cannot autofill an unreliable model or year',
    () async {
      final service = VinLookup(
        CatalogApi(baseUrl: ''),
        dio: respond(
          (_) => {
            'Results': [
              {
                'Make': 'BMW',
                'Model': 'Other trim',
                'ModelYear': '2001',
                'ErrorCode': '5,14',
              },
            ],
          },
        ),
      );
      final match = (await service.find('WBA1234561A000000')).single;
      expect(match.brand, 'BMW');
      expect(match.model, isEmpty);
      expect(match.year, isNull);
    },
  );
  test('a blank public decode falls back to the manufacturer only', () async {
    final calls = <String>[];
    final service = VinLookup(
      CatalogApi(baseUrl: ''),
      dio: respond((request) {
        calls.add(request.uri.path);
        return {
          'Results': [
            if (request.uri.path.endsWith('/DecodeWMI/TMB'))
              {'Make': 'SKODA', 'ManufacturerName': 'ŠKODA AUTO'}
            else
              {
                'Make': 'Not Applicable',
                'ModelYear': '2001',
                'ErrorCode': '14',
              },
          ],
        };
      }),
    );
    final match = (await service.find(skoda)).single;
    expect(calls, hasLength(2));
    expect(match.brand, 'SKODA');
    expect(match.model, isEmpty);
    expect(match.year, isNull);
    expect(match.catalogId, isEmpty);
  });

  test('a shared WMI offers separate makes without choosing one', () async {
    final service = VinLookup(
      CatalogApi(baseUrl: ''),
      dio: respond((request) {
        return {
          'Results': [
            if (request.uri.path.endsWith('/DecodeWMI/WDB'))
              {'Make': 'FIRST, SECOND', 'ManufacturerName': 'Group'}
            else
              {'ErrorCode': '14'},
          ],
        };
      }),
    );
    final matches = await service.find(mercedes);
    expect(matches.map((match) => match.brand), ['FIRST', 'SECOND']);
    expect(
      matches.every((match) => match.catalogId.isEmpty && match.year == null),
      isTrue,
    );
  });
  test(
    'FRAME goes only to the correct route and only an exact echo can bind fitment',
    () async {
      final service = VinLookup(
        CatalogApi(
          baseUrl: 'https://catalog.example.test',
          dio: respond((request) {
            expect(request.uri.path, '/frame');
            expect(request.data, {'frame': frame, 'market': 'JP'});
            return {
              'results': [
                {
                  'brand': 'Toyota',
                  'model': 'Prius',
                  'variant': 'ZVW30',
                  'id': 'model:1',
                  'verification': 'candidate',
                },
                {
                  'brand': 'Toyota',
                  'model': 'Prius',
                  'variant': 'ZVW30 1.8',
                  'id': 'frame:1',
                  'verification': 'exact',
                  'matchedIdentifier': frame,
                },
                {
                  'brand': 'Toyota',
                  'model': 'Prius',
                  'variant': 'Wrong',
                  'id': 'frame:2',
                  'verification': 'exact',
                  'matchedIdentifier': 'ZVW30-1234568',
                },
              ],
            };
          }),
        ),
        dio: respond((_) => fail('FRAME must not be sent to vPIC')),
      );
      final matches = await service.find(frame.toLowerCase());
      expect(matches, hasLength(2));
      expect(matches.first.catalogId, isEmpty);
      expect(matches.last.catalogId, 'frame:1');
    },
  );
}
