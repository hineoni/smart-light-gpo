// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Smart Light Control';

  @override
  String get devices => 'Devices';

  @override
  String get positioning => 'Positioning';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Theme';

  @override
  String get lightTheme => 'Light theme';

  @override
  String get darkTheme => 'Dark theme';

  @override
  String get emeraldTheme => 'Green theme';

  @override
  String get indigoTheme => 'Blue theme';

  @override
  String get language => 'Language';

  @override
  String get russian => 'Russian';

  @override
  String get english => 'English';

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutDescription => 'End the current session on this device';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutMessage =>
      'You will need to sign in again to manage your devices.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmSignOut => 'Sign out';

  @override
  String get myDevices => 'My devices';

  @override
  String get apiTest => 'API Test';

  @override
  String get noDevices => 'No devices';

  @override
  String get pullToRefresh => 'Pull down to refresh';

  @override
  String get retry => 'Retry';

  @override
  String get renameDevice => 'Rename device';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInToAccount => 'Sign in to your account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'No account? Register';

  @override
  String get register => 'Register';

  @override
  String get registration => 'Registration';

  @override
  String get createAccount => 'Create an account';

  @override
  String get name => 'Name';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get enterEmail => 'Enter your email';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get minimumSixCharacters => 'At least 6 characters';

  @override
  String get enterName => 'Enter your name';

  @override
  String get minimumTwoCharacters => 'At least 2 characters';

  @override
  String get repeatPassword => 'Repeat your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get invalidEmailOrPassword => 'Invalid email or password';

  @override
  String get registrationFailed => 'Could not register the user';

  @override
  String get addDevice => 'Add device';

  @override
  String get deviceName => 'Device name';

  @override
  String get optionalDeviceId => 'Device ID (optional)';

  @override
  String get optionalIpAddress => 'IP address (optional)';

  @override
  String get add => 'Add';

  @override
  String get deviceUnavailable => 'Device unavailable';

  @override
  String deviceUnavailableMessage(Object name) {
    return 'Device \"$name\" is not responding. Check the connection.';
  }

  @override
  String get lighting => 'Lighting';

  @override
  String get servoOne => 'Servo 1';

  @override
  String get servoTwo => 'Servo 2';

  @override
  String get refresh => 'Refresh';

  @override
  String errorWithDetails(Object details) {
    return 'Error: $details';
  }

  @override
  String get blePermissionsRequired => 'BLE permissions are required';

  @override
  String scanFailed(Object details) {
    return 'Scan failed: $details';
  }

  @override
  String get deviceConfigured =>
      'Device configured! 🎉\nAll settings were sent via BLE.';

  @override
  String get manualBackendSetup => 'Manual backend setup';

  @override
  String get manualBackendSetupDescription =>
      'Wi-Fi provisioning succeeded, but setting the backend URL failed. Enter the device IP address to configure it manually:';

  @override
  String get deviceIpAddress => 'Device IP address';

  @override
  String get deviceIpExample => 'e.g., 192.168.1.100';

  @override
  String get skip => 'Skip';

  @override
  String get setup => 'Set up';

  @override
  String get backendConfigured => 'Backend URL configured successfully!';

  @override
  String get manualSetupFailed =>
      'Manual setup failed. Check the device IP address.';

  @override
  String get bleProvisioning => 'BLE provisioning';

  @override
  String get scanning => 'Scanning…';

  @override
  String get scanForDevices => 'Scan for devices';

  @override
  String foundDevices(Object count) {
    return 'Found: $count';
  }

  @override
  String get scanningForDevices => 'Scanning for ESP32 devices…';

  @override
  String get noDevicesFound => 'No devices found. Tap \"Scan for devices\".';

  @override
  String get esp32Device => 'ESP32 device';

  @override
  String get fullDeviceConfiguration => 'Full device configuration';

  @override
  String get configurationDescription =>
      'All settings will be sent via BLE in one step.';

  @override
  String get wifiPassword => 'Wi-Fi password';

  @override
  String get selectDeviceFirst => 'Select a device first';

  @override
  String get provisioning => 'Provisioning…';

  @override
  String get provisionDevice => 'Provision device';

  @override
  String get webBleInstructions =>
      'Turn on Bluetooth and choose your ESP32 in the browser dialog. HTTPS and a browser with Web Bluetooth support are required (for example, Chrome, Edge, or Yandex Browser).';

  @override
  String get ambientLight => 'Light around the lamp';

  @override
  String get lightingAdvice => 'Lighting';

  @override
  String get ambientDark => 'Dark';

  @override
  String get ambientComfortable => 'Comfortable';

  @override
  String get ambientBright => 'Bright';

  @override
  String get ambientLoading => 'Reading sensor…';

  @override
  String get ambientNoData => 'No readings';

  @override
  String get ambientRefresh => 'Refresh readings';

  @override
  String get ambientSharedSensor => 'Updates automatically';

  @override
  String get ambientDeviceSensor => 'Updates automatically';

  @override
  String get ambientWaiting => 'Waiting for fresh sensor readings.';

  @override
  String get ambientConnectionError =>
      'Cannot reach the sensor. Check the USB connection.';

  @override
  String get ambientRelativeNote =>
      'Relative photoresistor scale, not lux. Readings update automatically.';

  @override
  String get lightingAdviceDescription =>
      'Suggest when to change the lamp brightness.';

  @override
  String get lightingAdviceDisabled => 'Advice is off';

  @override
  String get lightingAdviceDisabledDescription =>
      'Enable advice to get brightness suggestions.';

  @override
  String get lightingAdviceEnable => 'Enable advice';

  @override
  String get lightingAdviceDarkTitle => 'The room is dark';

  @override
  String get lightingAdviceDarkBody => 'Try increasing the lamp brightness.';

  @override
  String get lightingAdviceBrightTitle => 'It is too bright';

  @override
  String get lightingAdviceBrightBody => 'Try reducing the lamp brightness.';

  @override
  String get lightingAdviceComfortTitle => 'There is enough light';

  @override
  String get lightingAdviceComfortBody =>
      'No brightness change is needed right now.';

  @override
  String get lightingAdviceChooseLamp => 'Lamp with the sensor';

  @override
  String get lightingAdviceChooseLampHint => 'Select a lamp';

  @override
  String get lightingAdviceNoLamps =>
      'Add a lamp to apply suggestions. The shared sensor can be read without selecting a lamp.';

  @override
  String get lightingAdviceApply => 'Set to';

  @override
  String get lightingAdviceApplying => 'Applying…';

  @override
  String get lightingAdviceApplied => 'Lamp brightness updated';

  @override
  String get lightingAdviceApplyFailed =>
      'Could not change brightness. Check the lamp connection and try again.';

  @override
  String get lightingAdviceAtLimit =>
      'The lamp brightness is already at its limit. Try adjusting the room lighting.';

  @override
  String get lightingAdviceManualNote =>
      'The change depends on the sensor’s distance from 50%. Lamp brightness stays within 0–100%; color and position are preserved.';

  @override
  String get lightingAdviceHowItWorks => 'How it works';

  @override
  String get lightingAdviceThresholds =>
      '0% means dark, 100% means bright. At 35–65% there is enough light. The further the reading is from 50%, the larger the suggested brightness change. Lamp brightness stays within 0–100%. This is a relative scale, not lux.';

  @override
  String get lightingAdviceCurrentBrightness => 'Current lamp brightness';

  @override
  String get lightingAdviceCorrection => 'Lamp brightness change';

  @override
  String get lightingAdvicePoints => 'pp';

  @override
  String get lightingAdviceSensorLampMissing =>
      'The sensor’s lamp is not in this account. Check its Wi-Fi connection.';

  @override
  String get lampStateUnknown => 'Lamp state is not available yet';

  @override
  String get lampIsOff => 'Lamp is off';

  @override
  String get lampIsOn => 'Lamp is on';

  @override
  String get lampTurnOnAt => 'Turn on at';

  @override
  String get lampWaitingConfirmation => 'Waiting for the lamp to confirm…';

  @override
  String get lampCommandFailed =>
      'The lamp did not confirm the command. Check its connection.';
}
