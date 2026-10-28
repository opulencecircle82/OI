import 'dart:io';

import 'package:aisat_fap/models/cartridge.dart';
import 'package:aisat_fap/models/pram_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every PRAM card has a recording of every announcement', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final card in pramCards) {
      final dir = card.voiceFolder.isEmpty
          ? 'assets/pram'
          : 'assets/pram/${card.voiceFolder}';
      expect(pubspec, contains('- $dir/'), reason: '$dir not in pubspec');
      for (final item in pramLibrary) {
        final f = File('$dir/${item.id}.mp3');
        expect(f.existsSync(), isTrue, reason: '$dir/${item.id}.mp3 missing');
        expect(f.lengthSync(), greaterThan(10000));
      }
    }
  });
}
