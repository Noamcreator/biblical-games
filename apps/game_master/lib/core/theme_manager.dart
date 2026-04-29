import 'package:flutter/material.dart';

// On place les notifiers ici pour qu'ils soient accessibles partout
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<Color> accentColorNotifier = ValueNotifier(Colors.indigo);