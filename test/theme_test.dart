import 'package:car_care_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  testWidgets('manual theme overrides the system and survives a restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    Brightness screenBrightness() =>
        Theme.of(tester.element(find.byType(Scaffold).last)).brightness;

    Future<void> openSettings() async {
      await tester.tap(find.byTooltip('Настройки гаража'));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(const CarCareApp());
    await tester.pumpAndSettle();
    expect(screenBrightness(), Brightness.light);

    await openSettings();
    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    expect(screenBrightness(), Brightness.dark);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const CarCareApp());
    await tester.pumpAndSettle();
    expect(screenBrightness(), Brightness.dark);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await openSettings();
    await tester.tap(find.text('Светлая'));
    await tester.pumpAndSettle();
    expect(screenBrightness(), Brightness.light);
    await tester.tap(find.text('Как на телефоне'));
    await tester.pumpAndSettle();
    expect(screenBrightness(), Brightness.dark);
  });
}
