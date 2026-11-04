import 'package:flutter/material.dart';
import 'package:scooter_core/scooter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferenze utente, salvate solo sul dispositivo.
class SettingsController extends ChangeNotifier {
  static const _kTheme = 'theme_mode';
  static const _kVoice = 'voice_enabled';
  static const _kProfile = 'vehicle_profile';

  final SharedPreferences _prefs;

  SettingsController(this._prefs);

  ThemeMode get themeMode => switch (_prefs.getString(_kTheme)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_kTheme, mode.name);
    notifyListeners();
  }

  bool get voiceEnabled => _prefs.getBool(_kVoice) ?? true;

  Future<void> setVoiceEnabled(bool value) async {
    await _prefs.setBool(_kVoice, value);
    notifyListeners();
  }

  /// Profili selezionabili in questa versione: solo quelli supportati dal
  /// routing (oggi il ciclomotore). Gli altri sono visibili ma disabilitati.
  static bool isSelectable(VehicleProfile p) => ValhallaRequestBuilder.supports(p);

  VehicleProfile get vehicleProfile {
    final p = VehicleProfiles.byId(_prefs.getString(_kProfile) ?? '');
    return (p != null && isSelectable(p)) ? p : VehicleProfiles.a50cc;
  }

  Future<void> setVehicleProfile(VehicleProfile p) async {
    if (!isSelectable(p)) {
      throw ArgumentError('Profilo ${p.id} non ancora disponibile');
    }
    await _prefs.setString(_kProfile, p.id);
    notifyListeners();
  }
}
