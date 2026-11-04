/// Formattazione in italiano di distanze e tempi (testo e voce).
class FormatIt {
  /// Distanza arrotondata per la guida: <100 m a 10 m, <1 km a 50 m,
  /// altrimenti km con un decimale (fino a 10 km) o interi.
  static double roundGuidance(double m) {
    if (m < 100) return (m / 10).round() * 10.0;
    if (m < 1000) return (m / 50).round() * 50.0;
    return m;
  }

  static String _km(double m) {
    final km = m / 1000.0;
    if (km >= 10) return km.round().toString();
    return km.toStringAsFixed(1).replaceAll('.', ',');
  }

  /// "80 m", "450 m", "1,2 km", "15 km".
  static String distance(double m) {
    final r = roundGuidance(m);
    if (r < 1000) return '${r.round()} m';
    return '${_km(r)} km';
  }

  /// "80 metri", "1,2 chilometri", "1 chilometro".
  static String spokenDistance(double m) {
    final r = roundGuidance(m);
    if (r < 1000) return '${r.round()} metri';
    final k = _km(r);
    return k == '1,0' || k == '1' ? '1 chilometro' : '$k chilometri';
  }

  /// "45 s" (solo sotto il minuto), "12 min", "1 h 05 min".
  static String duration(double seconds) {
    final s = seconds.round();
    if (s < 60) return '$s s';
    final minutes = (s / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h h ${m.toString().padLeft(2, '0')} min';
  }

  /// Orario di arrivo "HH:MM" (ora locale del dispositivo).
  static String clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
