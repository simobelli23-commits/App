import 'package:flutter/material.dart';

/// Icona per i codici di manovra Valhalla (docs Valhalla, "maneuver types").
IconData maneuverIcon(int type) => switch (type) {
      1 || 2 || 3 => Icons.navigation,
      4 || 5 || 6 => Icons.flag,
      8 || 22 || 17 => Icons.straight,
      9 || 23 => Icons.turn_slight_right,
      10 => Icons.turn_right,
      11 => Icons.turn_sharp_right,
      12 => Icons.u_turn_right,
      13 => Icons.u_turn_left,
      14 => Icons.turn_sharp_left,
      15 => Icons.turn_left,
      16 || 24 => Icons.turn_slight_left,
      18 || 20 => Icons.ramp_right,
      19 || 21 => Icons.ramp_left,
      25 || 37 || 38 => Icons.merge,
      26 || 27 => Icons.roundabout_right,
      28 || 29 => Icons.directions_boat,
      _ => Icons.navigation,
    };
