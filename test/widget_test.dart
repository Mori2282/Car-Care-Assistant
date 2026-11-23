import 'package:car_care_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (width, scale) in [(320.0, 1.6), (800.0, 1.0)]) {
    testWidgets('add and reopen a car at width $width, text scale $scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const CarCareApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Добавить авто'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      for (final (i, value) in [
        (1, 'Škoda'),
        (2, 'Octavia Combi с длинным названием'),
        (3, '2018'),
        (4, '88000'),
      ]) {
        await tester.ensureVisible(fields.at(i));
        await tester.enterText(fields.at(i), value);
      }
      final save = find.text('Сохранить автомобиль');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Мой гараж'), findsOneWidget);
      expect(
        find.text('Škoda Octavia Combi с длинным названием'),
        findsOneWidget,
      );

      final parts = find.text('Запчасти');
      await tester.scrollUntilVisible(
        parts,
        220,
        scrollable:
            find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(parts);
      await tester.pumpAndSettle();
      expect(
        find.text('Для этого автомобиля пока нет сохранённых деталей.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const CarCareApp());
      await tester.pumpAndSettle();
      expect(
        find.text('Škoda Octavia Combi с длинным названием'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
