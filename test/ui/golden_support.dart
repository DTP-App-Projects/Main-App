import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app font and the Material icon font for golden renders.
///
/// Without these the test font draws every glyph as a filled box, which makes
/// a visual review impossible. The icon font ships with the Flutter SDK, not
/// the app, so it is read from `FLUTTER_ROOT` when available.
Future<void> loadGoldenFonts() async {
  final plex = FontLoader('IBMPlex');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    plex.addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-$weight.ttf'));
  }
  await plex.load();

  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final icons = File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (!icons.existsSync()) return;
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
  await loader.load();
}
