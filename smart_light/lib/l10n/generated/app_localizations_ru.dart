// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Управление умным светом';

  @override
  String get devices => 'Устройства';

  @override
  String get positioning => 'Расположение';

  @override
  String get settings => 'Настройки';

  @override
  String get appearance => 'Тема';

  @override
  String get lightTheme => 'Светлая тема';

  @override
  String get darkTheme => 'Тёмная тема';

  @override
  String get emeraldTheme => 'Зелёная тема';

  @override
  String get indigoTheme => 'Синяя тема';

  @override
  String get language => 'Язык';

  @override
  String get russian => 'Русский';

  @override
  String get english => 'Английский';

  @override
  String get account => 'Аккаунт';

  @override
  String get signOut => 'Выйти';

  @override
  String get signOutDescription => 'Завершить текущий сеанс на этом устройстве';

  @override
  String get signOutTitle => 'Выйти из аккаунта?';

  @override
  String get signOutMessage =>
      'Для управления устройствами потребуется войти снова.';

  @override
  String get cancel => 'Отмена';

  @override
  String get confirmSignOut => 'Выйти';

  @override
  String get myDevices => 'Мои устройства';

  @override
  String get apiTest => 'API Test';

  @override
  String get noDevices => 'Нет устройств';

  @override
  String get pullToRefresh => 'Потяните вниз для обновления';

  @override
  String get retry => 'Повторить';

  @override
  String get renameDevice => 'Переименовать устройство';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get signIn => 'Войти';

  @override
  String get signInToAccount => 'Войти в аккаунт';

  @override
  String get email => 'Email';

  @override
  String get password => 'Пароль';

  @override
  String get noAccountRegister => 'Нет аккаунта? Зарегистрироваться';

  @override
  String get register => 'Зарегистрироваться';

  @override
  String get registration => 'Регистрация';

  @override
  String get createAccount => 'Создать аккаунт';

  @override
  String get name => 'Имя';

  @override
  String get confirmPassword => 'Повторите пароль';

  @override
  String get alreadyHaveAccount => 'Уже есть аккаунт? Войти';

  @override
  String get enterEmail => 'Введите email';

  @override
  String get invalidEmail => 'Некорректный email';

  @override
  String get enterPassword => 'Введите пароль';

  @override
  String get minimumSixCharacters => 'Минимум 6 символов';

  @override
  String get enterName => 'Введите имя';

  @override
  String get minimumTwoCharacters => 'Минимум 2 символа';

  @override
  String get repeatPassword => 'Повторите пароль';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get invalidEmailOrPassword => 'Неверный email или пароль';

  @override
  String get registrationFailed => 'Не удалось зарегистрировать пользователя';

  @override
  String get addDevice => 'Добавить устройство';

  @override
  String get deviceName => 'Имя устройства';

  @override
  String get optionalDeviceId => 'ID устройства (опционально)';

  @override
  String get optionalIpAddress => 'IP адрес (опционально)';

  @override
  String get add => 'Добавить';

  @override
  String get deviceUnavailable => 'Устройство недоступно';

  @override
  String deviceUnavailableMessage(Object name) {
    return 'Устройство \"$name\" не отвечает. Проверьте подключение.';
  }

  @override
  String get lighting => 'Освещение';

  @override
  String get servoOne => 'Сервопривод 1';

  @override
  String get servoTwo => 'Сервопривод 2';

  @override
  String get refresh => 'Обновить';

  @override
  String errorWithDetails(Object details) {
    return 'Ошибка: $details';
  }

  @override
  String get blePermissionsRequired => 'Требуются разрешения для BLE';

  @override
  String scanFailed(Object details) {
    return 'Ошибка сканирования: $details';
  }

  @override
  String get deviceConfigured =>
      'Устройство настроено! 🎉\nВся конфигурация отправлена через BLE.';

  @override
  String get manualBackendSetup => 'Ручная настройка backend';

  @override
  String get manualBackendSetupDescription =>
      'Настройка Wi-Fi выполнена, но не удалось задать адрес backend. Введите IP-адрес устройства для ручной настройки:';

  @override
  String get deviceIpAddress => 'IP-адрес устройства';

  @override
  String get deviceIpExample => 'например, 192.168.1.100';

  @override
  String get skip => 'Пропустить';

  @override
  String get setup => 'Настроить';

  @override
  String get backendConfigured => 'Адрес backend успешно настроен!';

  @override
  String get manualSetupFailed =>
      'Ручная настройка не удалась. Проверьте IP-адрес устройства.';

  @override
  String get bleProvisioning => 'Настройка BLE';

  @override
  String get scanning => 'Сканирование…';

  @override
  String get scanForDevices => 'Найти устройства';

  @override
  String foundDevices(Object count) {
    return 'Найдено: $count';
  }

  @override
  String get scanningForDevices => 'Поиск устройств ESP32…';

  @override
  String get noDevicesFound =>
      'Устройства не найдены. Нажмите «Найти устройства».';

  @override
  String get esp32Device => 'Устройство ESP32';

  @override
  String get fullDeviceConfiguration => 'Полная настройка устройства';

  @override
  String get configurationDescription =>
      'Все параметры будут переданы через BLE за один шаг.';

  @override
  String get wifiPassword => 'Пароль Wi-Fi';

  @override
  String get selectDeviceFirst => 'Сначала выберите устройство';

  @override
  String get provisioning => 'Настройка…';

  @override
  String get provisionDevice => 'Настроить устройство';
}
