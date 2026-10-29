import 'dart:convert';
import 'dart:io';

import 'package:aisat_fap/models/cartridge.dart';
import 'package:aisat_fap/models/fap_state.dart';
import 'package:aisat_fap/providers/fap_provider.dart';
import 'package:aisat_fap/services/access_lock.dart';
import 'package:aisat_fap/services/update_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_audio.dart';

/// v4.0: passenger signs, lavatory calls, CAUT / event queue, flight phase,
/// cockpit PA, emergency lighting, CIDS loss, cartridges and in-app update.
void main() {
  late FakeAudio audio;
  late FapProvider fap;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AccessLock.androidIdReader = () async => null;
    audio = FakeAudio();
    fap = FapProvider(audio: audio);
  });

  tearDown(() => fap.dispose());

  group('passenger signs', () {
    test('at the gate: NO SMOKING (AUTO, gear down) on, seat belts off', () {
      expect(fap.flightPhase, FlightPhase.ground);
      expect(fap.noSmokingSignOn, isTrue);
      expect(fap.seatBeltSignOn, isFalse);
      expect(fap.returnToSeatOn, isFalse);
    });

    test('each sign change sounds one low chime', () {
      audio.calls.clear();
      fap.toggleSeatBeltSwitch();
      expect(fap.seatBeltSignOn, isTrue);
      expect(fap.returnToSeatOn, isTrue);
      expect(audio.calls, ['chime:singleLow']);

      // Gear up: NO SMOKING in AUTO goes off -> chime.
      audio.calls.clear();
      fap.setFlightPhase(FlightPhase.flight);
      expect(fap.noSmokingSignOn, isFalse);
      expect(audio.calls, ['chime:singleLow']);

      // No change of any sign -> no chime.
      audio.calls.clear();
      fap.setFlightPhase(FlightPhase.enginesRunning); // gear down: NS on
      audio.calls.clear();
      fap.setNoSmokingSwitch(SignSwitch.on); // already on
      expect(audio.calls, isEmpty);
    });

    test('CIDS 1+2 FAULT loses the signs', () {
      fap.toggleSeatBeltSwitch();
      fap.toggleDirectorFault(1);
      fap.toggleDirectorFault(2);
      expect(fap.seatBeltSignOn, isFalse);
      expect(fap.noSmokingSignOn, isFalse);
    });
  });

  group('emergency lighting', () {
    test('ARM: on by itself when normal power is lost', () {
      expect(fap.emerExitLtSwitch, EmerLtSwitch.arm);
      expect(fap.emerLights, isFalse);
      fap.toggleNormalPowerLost();
      expect(fap.emerLights, isTrue);
      fap.setEmerExitLt(EmerLtSwitch.off);
      expect(fap.emerLights, isFalse);
      fap.setEmerExitLt(EmerLtSwitch.on);
      fap.toggleNormalPowerLost();
      expect(fap.emerLights, isTrue);
    });

    test('FAP EMER key works on its own', () {
      fap.toggleEmerLights();
      expect(fap.emerKeyOn, isTrue);
      expect(fap.emerLights, isTrue);
    });

    test('EXIT signs in ARM follow NO SMOKING', () {
      expect(fap.exitSignsOn, isTrue); // AUTO + gear down
      fap.setNoSmokingSwitch(SignSwitch.off);
      expect(fap.exitSignsOn, isFalse);
    });
  });

  group('lavatory calls', () {
    test('call, caution row, second press cancels, CALL RESET clears', () {
      audio.calls.clear();
      fap.lavCall(Lavatory.d);
      expect(audio.calls, ['chime:singleHigh']);
      expect(fap.caution.text, 'PAX CALL  LAV D');
      fap.lavCall(Lavatory.d);
      expect(fap.lavCalls, isEmpty);
      fap.lavCall(Lavatory.a);
      fap.simulatePaxCall();
      expect(fap.allCalls.length, 2);
      fap.callReset();
      expect(fap.allCalls, isEmpty);
    });

    test('CHIME INHIB silences the lavatory call chime', () {
      fap.toggleChimeInhibit();
      audio.calls.clear();
      fap.lavCall(Lavatory.e);
      expect(audio.calls, isEmpty);
      expect(fap.lavCalls, [Lavatory.e]);
    });
  });

  group('CAUT key and event queue', () {
    test('off, flashing for a new event, steady once its page is seen', () {
      expect(fap.cautState, CautState.off);
      fap.goTo(FapPage.lights);
      for (var i = 0; i < 10; i++) {
        fap.addWaste();
      }
      expect(fap.cautState, CautState.flashing);
      expect(fap.infoPage, FapPage.water);
      fap.cautPressed();
      expect(fap.page, FapPage.water);
      expect(fap.cautState, CautState.steady);
      expect(fap.infoPage, isNull);
      fap.drainWaste();
      expect(fap.cautState, CautState.off);
    });

    test('smoke opens its page itself, so it is never left unseen', () {
      fap.goTo(FapPage.audio);
      fap.triggerSmoke(Lavatory.a);
      expect(fap.page, FapPage.smoke);
      expect(fap.cautState, CautState.steady);
    });

    test('SCREEN OFF steps through new events before blanking', () {
      fap.goTo(FapPage.lights);
      fap.lavCall(Lavatory.a);
      fap.screenOffKey();
      expect(fap.page, FapPage.audio);
      expect(fap.screenOff, isFalse);
      fap.screenOffKey();
      expect(fap.screenOff, isTrue);
    });
  });

  group('flight phase and layout selection', () {
    test('layout selection is ground only', () {
      fap.setFlightPhase(FlightPhase.flight);
      expect(fap.layoutSelectionBlocks, ['IN FLIGHT']);
      fap.selectLayoutRow(1);
      fap.loadLayout();
      expect(fap.activeLayout.id, 3);
      fap.setFlightPhase(FlightPhase.ground);
      fap.loadLayout();
      expect(fap.activeLayout.id, 1);
    });

    test('CABIN READY text follows the phase', () {
      fap.toggleCabinReady();
      expect(fap.notice!.text, contains('AFTER ENGINE START'));
      fap.toggleCabinReady();
      fap.setFlightPhase(FlightPhase.enginesRunning);
      fap.toggleCabinReady();
      expect(fap.notice!.text, 'CABIN READY SENT TO COCKPIT');
    });
  });

  group('cockpit PA', () {
    test('has priority: stops the PRAM and lowers the music', () async {
      fap.bgmToggle();
      await fap.playSelectedPram();
      expect(fap.playingAnnouncement, isNotNull);
      audio.calls.clear();
      fap.toggleCockpitPa();
      expect(audio.calls, contains('stopAnnouncement'));
      expect(fap.playingAnnouncement, isNull);
      expect(audio.otherPa, isTrue);
      expect(fap.musicPlaying, isTrue); // lowered, not stopped

      audio.calls.clear();
      await fap.playSelectedPram();
      expect(audio.calls.where((c) => c.startsWith('announce')), isEmpty);

      fap.toggleCockpitPa();
      expect(audio.otherPa, isFalse);
      await fap.playSelectedPram();
      expect(audio.calls, contains('announce:welcome'));
    });

    test('the captain speaks, and the PA ends when the captain finishes', () {
      fap.toggleCockpitPa();
      expect(audio.calls, contains('cockpitPa'));
      expect(audio.cockpitPa, isTrue);
      audio.finishCockpitPa();
      expect(fap.cockpitPa, isFalse);
      expect(audio.otherPa, isFalse);

      // The key again ends it early.
      fap.toggleCockpitPa();
      fap.toggleCockpitPa();
      expect(audio.cockpitPa, isFalse);
      expect(fap.cockpitPa, isFalse);
    });

    test('the bundled captain voice exists', () {
      expect(File('assets/pa/captain_pa.mp3').lengthSync(), greaterThan(10000));
    });
  });

  group('loss of the CIDS', () {
    test('lights go full bright after 3 minutes, lav lights dim on return', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        f.setGeneralLight(LightLevel.dim2);
        f.toggleLavMaint();
        f.toggleDirectorFault(1);
        f.toggleDirectorFault(2);
        f.toggleMainLights(); // no light control without the CIDS
        expect(f.generalLevel, LightLevel.dim2);
        async.elapse(const Duration(minutes: 2, seconds: 59));
        expect(f.generalLevel, LightLevel.dim2);
        async.elapse(const Duration(seconds: 1));
        expect(f.generalLevel, LightLevel.bright);
        expect(f.cidsLightsFull, isTrue);
        f.toggleDirectorFault(2);
        expect(f.cidsLightsFull, isFalse);
        expect(f.lavMaint, isFalse);
        expect(f.generalLevel, LightLevel.bright);
        f.dispose();
      });
    });

    test('a restored director before 3 minutes keeps the lights', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        f.setGeneralLight(LightLevel.dim1);
        f.toggleDirectorFault(1);
        f.toggleDirectorFault(2);
        async.elapse(const Duration(minutes: 1));
        f.toggleDirectorFault(1);
        async.elapse(const Duration(minutes: 5));
        expect(f.generalLevel, LightLevel.dim1);
        f.dispose();
      });
    });
  });

  group('cartridges', () {
    test('PRAM: REMOVE, insert another card, OK -> new voice', () async {
      fap.bgmToggle();
      fap.removeCard(CardSlot.pram);
      expect(fap.pramAvailable, isFalse);
      expect(fap.musicPlaying, isFalse);
      audio.calls.clear();
      await fap.playSelectedPram();
      expect(audio.calls, isEmpty);

      fap.pickCard(CardSlot.pram, 'pram_aria');
      fap.insertCard(CardSlot.pram);
      expect(fap.pramAvailable, isFalse); // not until OK
      fap.confirmCard(CardSlot.pram);
      expect(fap.pramCard!.id, 'pram_aria');
      await fap.playSelectedPram();
      expect(audio.calls, contains('announce:aria/welcome'));
    });

    test('a full slot cannot take a second card; OK needs a card', () {
      fap.insertCard(CardSlot.pram);
      expect(fap.notice!.text, contains('SLOT IS FULL'));
      fap.removeCard(CardSlot.cam);
      fap.confirmCard(CardSlot.cam);
      expect(fap.notice!.text, contains('NO CARD'));
      expect(fap.slotPending(CardSlot.cam), isTrue);
    });

    test('CAM: the new layouts are loaded by hand', () {
      fap.removeCard(CardSlot.cam);
      expect(fap.layoutSelectionBlocks, ['NO CAM IN SLOT']);
      fap.pickCard(CardSlot.cam, 'cam_b');
      fap.insertCard(CardSlot.cam);
      fap.confirmCard(CardSlot.cam);
      expect([for (final l in fap.slotLayouts) l.id], [11, 12, 13]);
      expect(fap.activeLayout.id, 3); // the CIDS keeps the old layout
      fap.loadLayout(); // nothing of CAM B selected yet
      expect(fap.activeLayout.id, 3);
      fap.selectLayoutRow(11);
      fap.loadLayout();
      expect(fap.activeLayout.rows, 31);
      expect(fap.activeCam.id, 'cam_b');
      expect(fap.activeZones, [
        LightZone.fwdEntry,
        LightZone.tourist,
        LightZone.aftEntry,
      ]);
    });

    test('CAM: SAVE needs the CAM of the active layout in the slot', () {
      fap.removeCard(CardSlot.cam);
      fap.pickCard(CardSlot.cam, 'cam_b');
      fap.insertCard(CardSlot.cam);
      fap.confirmCard(CardSlot.cam);
      fap.selectBoundary(1);
      fap.moveBoundary(1);
      fap.saveProgramming();
      expect(fap.layoutCount(3), 0);
      expect(fap.notice!.text, contains('NOT THE CAM OF THE ACTIVE LAYOUT'));
    });

    test('OBRM: software follows the card in the slot', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        expect(f.swUpdated, isFalse);
        f.loadSoftware();
        async.elapse(const Duration(seconds: 11));
        expect(f.swUpdated, isTrue);
        expect(f.activeSoftware.id, 'obrm_b');
        async.elapse(const Duration(seconds: 5));
        f.removeCard(CardSlot.obrm);
        f.loadSoftware();
        expect(f.swProgress, isNull);
        expect(f.notice!.text, 'NO OBRM IN SLOT');
        f.pickCard(CardSlot.obrm, 'obrm_a');
        f.insertCard(CardSlot.obrm);
        f.confirmCard(CardSlot.obrm);
        expect(f.swUpdated, isFalse);
        f.dispose();
      });
    });

    test('the OBRM cannot be removed while software loads', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        f.loadSoftware();
        f.removeCard(CardSlot.obrm);
        expect(f.cardInSlot(CardSlot.obrm), isNotNull);
        async.elapse(const Duration(seconds: 20));
        f.dispose();
      });
    });

    test(
      'cards, phase and switches survive a restart; reset restores',
      () async {
        fakeAsync((async) {
          final f = FapProvider(audio: audio);
          f.removeCard(CardSlot.pram);
          f.pickCard(CardSlot.pram, 'pram_sonia');
          f.insertCard(CardSlot.pram);
          f.confirmCard(CardSlot.pram);
          f.removeCard(CardSlot.obrm); // left empty
          f.setFlightPhase(FlightPhase.flight);
          f.toggleSeatBeltSwitch();
          f.setEmerExitLt(EmerLtSwitch.off);
          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
          f.dispose();
        });
        final r = FapProvider(audio: FakeAudio());
        await r.load();
        expect(r.pramCard!.id, 'pram_sonia');
        expect(r.cardInSlot(CardSlot.obrm), isNull);
        expect(r.slotPending(CardSlot.obrm), isTrue);
        expect(r.flightPhase, FlightPhase.flight);
        expect(r.seatBeltSwitch, isTrue);
        expect(r.emerExitLtSwitch, EmerLtSwitch.off);
        r.resetSimulator();
        expect(r.pramCard!.id, 'pram_orig');
        expect(r.cardInSlot(CardSlot.obrm)!.id, 'obrm_b');
        expect(r.flightPhase, FlightPhase.ground);
        r.dispose();
      },
    );

    test('a v3.x save with the software loaded keeps it loaded', () async {
      SharedPreferences.setMockInitialValues({
        'fap_state_v1': jsonEncode({'swUpdated': true, 'layout': 2}),
      });
      final r = FapProvider(audio: FakeAudio());
      await r.load();
      expect(r.swUpdated, isTrue);
      expect(r.activeLayout.id, 2);
      expect(r.pramAvailable, isTrue);
      r.dispose();
    });
  });

  group('in-app update', () {
    tearDown(() {
      UpdateService.clientFactory = http.Client.new;
    });

    test('version comparison', () {
      expect(UpdateService.isNewer('4.1', '4.0'), isTrue);
      expect(UpdateService.isNewer('4.0', '4.0'), isFalse);
      expect(UpdateService.isNewer('3.10', '3.9'), isTrue);
      expect(UpdateService.isNewer('4.0.1', '4.0'), isTrue);
      expect(UpdateService.isNewer('3.9', '4.0'), isFalse);
    });

    UpdateCheck? result;
    Future<void> checkWith(String body, {String platform = 'android'}) async {
      UpdateService.platformName = () => platform;
      UpdateService.clientFactory = () =>
          MockClient((_) async => http.Response(body, 200));
      result = await UpdateService.checkNow(current: '4.0');
    }

    final manifest = {
      'version': '4.1',
      'notes': ['New page'],
      'android': {
        'url':
            'https://github.com/x/releases/download/v4.1.0/A320_FAP_v4.1.apk',
        'name': 'A320_FAP_v4.1.apk',
      },
      'windows': {
        'url': 'https://github.com/x/releases/download/v4.1.0/A320_FAP_Setup_v4.1.exe',
        'name': 'A320_FAP_Setup_v4.1.exe',
      },
    };

    test('newer version: the file for this platform', () async {
      await checkWith(jsonEncode(manifest));
      expect(result!.status, UpdateStatus.available);
      expect(result!.info!.fileName, 'A320_FAP_v4.1.apk');
      expect(result!.info!.notes, ['New page']);
      await checkWith(jsonEncode(manifest), platform: 'windows');
      expect(result!.info!.fileName, 'A320_FAP_Setup_v4.1.exe');
    });

    test('same version, web, bad data or offline: no update', () async {
      await checkWith(jsonEncode({...manifest, 'version': '4.0'}));
      expect(result!.status, UpdateStatus.upToDate);
      await checkWith(jsonEncode(manifest), platform: 'web');
      expect(result!.status, UpdateStatus.unavailable);
      await checkWith('not json');
      expect(result!.status, UpdateStatus.unavailable);
      await checkWith(
        jsonEncode({
          ...manifest,
          'android': {'url': 'https://x/a.apk', 'name': '../../evil.apk'},
        }),
      );
      expect(result!.status, UpdateStatus.unavailable);
      await checkWith(
        jsonEncode({
          ...manifest,
          'android': {'url': 'http://x/a.apk', 'name': 'a.apk'},
        }),
      );
      expect(result!.status, UpdateStatus.unavailable);
      UpdateService.platformName = () => 'android';
      UpdateService.clientFactory = () =>
          MockClient((_) async => throw http.ClientException('offline'));
      expect(await UpdateService.check(current: '4.0'), isNull);
    });
  });
}
