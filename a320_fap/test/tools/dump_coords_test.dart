// Dumps the on-screen position of every text, icon and slider on each FAP
// page, in FAP design coordinates (1350 x 940 device canvas). Used by the
// tutorial video recorder to know where to tap.
//
//   flutter test test/tools/dump_coords_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:aisat_fap/main.dart';
import 'package:aisat_fap/models/cartridge.dart';
import 'package:aisat_fap/models/fap_state.dart';
import 'package:aisat_fap/providers/fap_provider.dart';
import 'package:aisat_fap/services/access_lock.dart';
import 'package:aisat_fap/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_audio.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final bytes = File(p).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  final root = Platform.environment['FLUTTER_ROOT'] ?? 'D:/dev/flutter';
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  await load('Roboto', [
    '$fonts/roboto-regular.ttf',
    '$fonts/roboto-medium.ttf',
    '$fonts/roboto-bold.ttf',
    '$fonts/roboto-black.ttf',
  ]);
  await load('MaterialIcons', ['$fonts/materialicons-regular.otf']);
  await load('JetBrainsMono', [
    'assets/fonts/JetBrainsMono-Regular.ttf',
    'assets/fonts/JetBrainsMono-Bold.ttf',
  ]);
}

void main() {
  testWidgets('dump coordinates', (tester) async {
    await _loadFonts();
    // As in the recording browser (web build): the device id of the
    // tutorial recording, license server not reached, no update check.
    const recDevice = 'tutorial0recording0device0000000';
    SharedPreferences.setMockInitialValues({
      'fap_device_id': recDevice,
      'fap_license_v2': recDevice,
    });
    AccessLock.androidIdReader = () async => null;
    AccessLock.clientFactory = () =>
        MockClient((_) async => throw http.ClientException('offline'));
    UpdateService.platformName = () => 'web';
    tester.view.physicalSize = const Size(1350, 940);
    tester.view.devicePixelRatio = 1;
    final fap = FapProvider(audio: FakeAudio());
    await tester.pumpWidget(AisatFapApp(fap: fap));
    await tester.pump(const Duration(milliseconds: 300));

    Map<String, dynamic> rect(Rect r) => {
      'x': r.center.dx,
      'y': r.center.dy,
      'l': r.left,
      't': r.top,
      'w': r.width,
      'h': r.height,
    };

    final out = <String, dynamic>{};
    // The notice shown at every start comes first (stored as 'disclaimer'),
    // then every page as first seen, the protected pages once unlocked
    // ('<page>_open'), and a few states used by the tutorial video.
    final shots = <(FapPage, String)>[
      (FapPage.lights, 'disclaimer'),
      for (final p in FapPage.values) (p, p.name),
      for (final p in FapPage.values.where((p) => p.protected))
        (p, '${p.name}_open'),
      (FapPage.cabinProg, 'cabinProg_saved'),
      (FapPage.fapSetup, 'fapSetup_pramRemoved'),
      (FapPage.audio, 'audio_noPram'),
      (FapPage.layout, 'layout_camB'),
      // The INSTRUCTOR panel, one state per tab (over CABIN STATUS).
      for (final t in InstructorTab.values)
        (FapPage.cabinStatus, 'instructor_${t.name}'),
    ];
    for (final (p, key) in shots) {
      if (key == 'cabinStatus') {
        // Leave the notice for the panel.
        await tester.tap(find.text('I AGREE & CONTINUE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      if (key.endsWith('_open')) {
        fap.enterAccessCode(p, p == FapPage.swLoad ? '813' : '318');
      }
      if (key == 'cabinProg_saved') {
        fap.moveBoundary(1);
        fap.saveProgramming();
      }
      if (key == 'fapSetup_pramRemoved') {
        fap.dismissSaved();
        fap.removeCard(CardSlot.pram);
      }
      if (key == 'layout_camB') {
        fap.pickCard(CardSlot.pram, 'pram_aria');
        fap.insertCard(CardSlot.pram);
        fap.confirmCard(CardSlot.pram);
        fap.removeCard(CardSlot.cam);
        fap.pickCard(CardSlot.cam, 'cam_b');
        fap.insertCard(CardSlot.cam);
        fap.confirmCard(CardSlot.cam);
      }
      if (key.startsWith('instructor_')) {
        fap.goTo(p);
        if (!fap.instructorOpen) fap.toggleInstructor();
        fap.setInstructorTab(
          InstructorTab.values.byName(key.substring('instructor_'.length)),
        );
      } else if (key != 'disclaimer') {
        fap.goTo(p);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final texts = <Map<String, dynamic>>[];
      for (final e in find.byType(Text).evaluate()) {
        final w = e.widget as Text;
        final s = w.data ?? w.textSpan?.toPlainText();
        if (s == null || s.trim().isEmpty) continue;
        final box = e.renderObject as RenderBox?;
        if (box == null || !box.hasSize) continue;
        final r = box.localToGlobal(Offset.zero) & box.size;
        texts.add({'text': s, ...rect(r)});
      }
      final icons = <Map<String, dynamic>>[];
      for (final e in find.byType(Icon).evaluate()) {
        final w = e.widget as Icon;
        final box = e.renderObject as RenderBox?;
        if (w.icon == null || box == null || !box.hasSize) continue;
        final r = box.localToGlobal(Offset.zero) & box.size;
        icons.add({'icon': w.icon!.codePoint, ...rect(r)});
      }
      final sliders = <Map<String, dynamic>>[];
      for (final e in find.byType(Slider).evaluate()) {
        final box = e.renderObject as RenderBox?;
        if (box == null || !box.hasSize) continue;
        sliders.add(rect(box.localToGlobal(Offset.zero) & box.size));
      }
      // Named regions (panels, cards, diagram, bars) for highlight boxes.
      const regionTypes = {
        'TopStatusBar',
        '_TitleBar',
        'BottomTouchNav',
        'HardwareBezelStrip',
        'AircraftDiagram',
        'FapPanel',
        '_FrameKey',
        '_DoorCard',
        '_TileView',
        '_LavCard',
        '_ZoneCard',
        '_Gauge',
        '_LavTile',
        '_SummaryBar',
        '_ResetHint',
        '_EvacCmdKey',
        '_HardKey',
        'AccessKeypad',
        '_SavedDialog',
        '_SeatMap',
        '_CockpitTrainer',
        '_CartridgePanel',
        '_CardCase',
        '_CardSlot',
        'InstructorPanel',
        '_Group',
      };
      final regions = <Map<String, dynamic>>[];
      for (final e
          in find
              .byWidgetPredicate(
                (w) => regionTypes.contains(w.runtimeType.toString()),
              )
              .evaluate()) {
        final box = e.renderObject as RenderBox?;
        if (box == null || !box.hasSize) continue;
        final labels = <String>[];
        void walk(Element x) {
          if (labels.length >= 3) return;
          final w = x.widget;
          if (w is Text && (w.data ?? '').trim().isNotEmpty) {
            labels.add(w.data!);
          }
          x.visitChildElements(walk);
        }

        e.visitChildElements(walk);
        regions.add({
          'type': e.widget.runtimeType.toString(),
          'labels': labels,
          ...rect(box.localToGlobal(Offset.zero) & box.size),
        });
      }
      out[key] = {
        'texts': texts,
        'icons': icons,
        'sliders': sliders,
        'regions': regions,
      };
    }

    File('build/fap_coords.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
        'device': {'w': 1350, 'h': 940},
        'icons': {
          'add': Icons.add.codePoint,
          'remove': Icons.remove.codePoint,
          'play': Icons.play_arrow.codePoint,
          'stop': Icons.stop.codePoint,
          'arrow_forward': Icons.arrow_forward.codePoint,
          'arrow_back': Icons.arrow_back.codePoint,
          'arrow_left': Icons.arrow_left.codePoint,
          'arrow_right': Icons.arrow_right.codePoint,
          'up': Icons.keyboard_arrow_up.codePoint,
          'down': Icons.keyboard_arrow_down.codePoint,
          'close': Icons.close.codePoint,
        },
        'pages': out,
      }),
    );

    await tester.pumpWidget(const SizedBox());
    fap.dispose();
    tester.view.reset();
  });
}
