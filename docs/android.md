# Android и Google Play

Среда проекта: Flutter 3.29.0, JDK 17, Android SDK 36, Build Tools 35.0.0. Минимальная версия Android 6.0 (API 23), целевая API 36.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`. AAB: `build/app/outputs/bundle/release/app-release.aab`. GitHub Actions проверяет оба формата. Без ключа команда создаёт подписанную отладочным сертификатом сборку для проверки. Для загрузки в Google Play настройте ключ загрузки и Play App Signing.

Переменные для подписи: `CAR_CARE_KEYSTORE` (абсолютный путь), `CAR_CARE_STORE_PASSWORD`, `CAR_CARE_KEY_ALIAS`, `CAR_CARE_KEY_PASSWORD`. Храните ключ и пароли вне репозитория. Перед созданием карточки Play Console выберите постоянный идентификатор пакета. Если изменится идентификатор или сертификат, перенесите данные с помощью файла резервной копии.

Перед публикацией проверьте установку через внутренний трек, нативные библиотеки на 16 КБ, восстановление копии, уведомление по дате, сканирование с крупным шрифтом и TalkBack на реальном телефоне. Потребуются карточка приложения с актуальными скриншотами, контакты поддержки, публичная политика конфиденциальности и форма Data safety. Проверяйте требования закрытого теста в самой Play Console.

[Требования к целевому API](https://support.google.com/googleplay/android-developer/answer/11926878) · [Подпись приложения](https://developer.android.com/studio/publish/app-signing) · [Проверка 16 КБ](https://developer.android.com/guide/practices/page-sizes)
