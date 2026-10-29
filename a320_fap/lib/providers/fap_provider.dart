import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cabin_setup.dart';
import '../models/cartridge.dart';
import '../models/fap_state.dart';
import '../models/pram_item.dart';
import '../services/fap_audio.dart';
import '../theme/fap_theme.dart';
import '../widgets/top_status_bar.dart' show fapClockNow;

/// One line in the FAP caution / info row.
class CautionMessage {
  const CautionMessage(this.text, this.color, {this.flashing = false});
  final String text;
  final Color color;
  final bool flashing;
}

/// Transient feedback shown on the screen for a few seconds.
class FapNotice {
  const FapNotice(this.id, this.text, this.color);
  final int id;
  final String text;
  final Color color;
}

/// Complete A320 CIDS FAP simulator state and logic. Everything is local:
/// persistent settings are stored with SharedPreferences, alarms are not.
class FapProvider extends ChangeNotifier {
  FapProvider({FapAudio? audio, Random? random})
    : audio = audio ?? FapAudio(),
      _random = random ?? Random() {
    this.audio.onAnnouncementDone = _onAnnouncementDone;
    this.audio.onCockpitPaDone = _onCockpitPaDone;
    this.audio.setPaGain(_paGain);
    this.audio.setMusicLevel(_musicLevel);
    _applyAudioOutput();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  static const _prefsKey = 'fap_state_v1';

  final FapAudio audio;
  late final Timer _tick;
  SharedPreferences? _prefs;
  Timer? _saveTimer;
  Timer? _noticeTimer;
  Timer? _lockTimer;
  Timer? _restartTimer;
  Timer? _swTimer;
  Timer? _playAllTimer;
  Timer? _cidsLightTimer;
  final Random _random;
  bool _disposed = false;

  @override
  void notifyListeners() {
    _syncEvents();
    super.notifyListeners();
  }

  // ------------------------------------------------------------ navigation

  FapPage _page = FapPage.lights;
  FapPage get page => _page;
  int _bank = 1;

  /// Which row of page tabs is shown (1 = cabin pages, 2 = CAM pages).
  int get bank => _bank;

  void goTo(FapPage p) {
    if (_page == p && _bank == p.bank) return;
    _page = p;
    _bank = p.bank;
    notifyListeners();
  }

  /// The arrows at both ends of the tab bar switch between the two rows.
  void setBank(int b) {
    if (_bank == b) return;
    _bank = b;
    notifyListeners();
  }

  // Access codes for the protected CAM / maintenance pages.
  final Set<FapPage> _granted = {};
  bool accessGranted(FapPage p) => !p.protected || _granted.contains(p);

  /// Returns true when [code] opens page [p] (CIDS default codes).
  bool enterAccessCode(FapPage p, String code) {
    final need = p == FapPage.swLoad
        ? SetupLimits.softwareCode
        : SetupLimits.programmingCode;
    if (code == need) {
      _granted.add(p);
      notifyListeners();
      return true;
    }
    _showNotice('INVALID ACCESS CODE', color: FapColors.red);
    notifyListeners();
    return false;
  }

  // ------------------------------------------------------------ screen

  bool _screenOff = false;
  bool get screenOff => _screenOff;

  /// SCREEN OFF: blanks the display; a touch wakes it up.
  void setScreenOff(bool off) {
    _screenOff = off;
    notifyListeners();
  }

  /// SCREEN OFF key: while new events wait to be read it steps through
  /// their pages one at a time; otherwise it blanks the display.
  void screenOffKey() {
    final next = infoPage;
    if (next != null) {
      goTo(next);
    } else {
      setScreenOff(true);
    }
  }

  // ------------------------------------------------------------ CAUT / events

  // Each event that has a page: smoke, deployed slides, water / waste,
  // CIDS faults and calls. An event is "new" until its page is selected.
  final Set<String> _knownEvents = {};
  final Set<String> _unseenEvents = {};

  Map<String, FapPage> get _activeEvents => {
    for (final l in smokeLavs) 'smoke:${l.name}': FapPage.smoke,
    for (final d in deployedDoors) 'slide:${d.name}': FapPage.doors,
    if (lavsInop) 'wasteFull': FapPage.water,
    if (waterLow) 'waterLow': FapPage.water,
    if (cidsDown)
      'cids': FapPage.systemInfo
    else if (_dir1Fault || _dir2Fault)
      'dir${_dir1Fault ? 1 : 2}': FapPage.systemInfo,
    for (final s in _paxCalls) 'call:$s': FapPage.audio,
    for (final l in _lavCalls) 'lav:${l.name}': FapPage.audio,
  };

  void _syncEvents() {
    final active = _activeEvents;
    _knownEvents.removeWhere((k) => !active.containsKey(k));
    _unseenEvents.removeWhere((k) => !active.containsKey(k));
    for (final k in active.keys) {
      if (_knownEvents.add(k)) _unseenEvents.add(k);
    }
    _unseenEvents.removeWhere((k) => active[k] == _page);
  }

  CautState get cautState {
    if (_knownEvents.isEmpty) return CautState.off;
    return _unseenEvents.isEmpty ? CautState.steady : CautState.flashing;
  }

  /// Page of the oldest new event (shown in the info row), if any.
  FapPage? get infoPage {
    final active = _activeEvents;
    for (final e in active.entries) {
      if (_unseenEvents.contains(e.key)) return e.value;
    }
    return null;
  }

  /// CAUT key: opens the page of the next new event (or of the first
  /// active one when all have been seen).
  void cautPressed() {
    final active = _activeEvents;
    final next = infoPage ?? (active.isEmpty ? null : active.values.first);
    if (next != null) goTo(next);
  }

  bool _configOpen = false;
  bool get configOpen => _configOpen;

  bool _showTrainer = true;
  bool get showTrainer => _showTrainer;

  /// SETTINGS > TRAINER CONTROLS: the dashed TRAINER boxes and the FAP
  /// CONFIG key are not on the real A320 FAP. Hidden, only the real FAP is
  /// on screen (e.g. for an assessment).
  void setShowTrainer(bool show) {
    _showTrainer = show;
    if (!show) _configOpen = false;
    _changed();
  }

  /// FAP CONFIG panel (simulator settings) open / closed.
  void toggleConfig() {
    _configOpen = !_configOpen;
    notifyListeners();
  }

  bool _cabinReady = false;
  bool get cabinReady => _cabinReady;

  /// CABIN READY: tells the flight crew the cabin is secured. The ECAM
  /// shows it on the take-off checklist once the engines run and on the
  /// landing checklist with the gear down.
  void toggleCabinReady() {
    _cabinReady = !_cabinReady;
    final String text;
    if (!_cabinReady) {
      text = 'CABIN READY CANCELLED';
    } else if (_phase == FlightPhase.enginesRunning ||
        _phase == FlightPhase.approach) {
      text = 'CABIN READY SENT TO COCKPIT';
    } else if (_phase == FlightPhase.ground) {
      text = 'CABIN READY SET - SHOWN TO COCKPIT AFTER ENGINE START';
    } else {
      text = 'CABIN READY SET - SHOWN TO COCKPIT ON APPROACH';
    }
    _showNotice(text, color: _cabinReady ? FapColors.okGreen : FapColors.amber);
    _changed();
  }

  FapNotice? _notice;
  int _noticeSeq = 0;
  FapNotice? get notice => _notice;

  void _showNotice(String text, {Color color = FapColors.amber}) {
    _notice = FapNotice(++_noticeSeq, text, color);
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (_disposed) return;
      _notice = null;
      notifyListeners();
    });
  }

  // ------------------------------------------------------------ lighting

  final Map<LightZone, LightLevel> _lights = {
    for (final z in LightZone.values) z: LightLevel.bright,
  };
  bool _windowLights = true;
  bool _aisleLights = true;
  bool _readingAll = false;
  bool _attWorkLights = true;
  bool _lavMaint = false;
  bool _emerLights = false;

  LightLevel lightLevel(LightZone z) => _lights[z]!;
  bool get windowLights => _windowLights;
  bool get aisleLights => _aisleLights;
  bool get readingAll => _readingAll;
  bool get attWorkLights => _attWorkLights;
  bool get lavMaint => _lavMaint;

  /// EMER hard key of the FAP.
  bool get emerKeyOn => _emerLights;

  /// Cabin emergency lighting: from the FAP EMER key, the cockpit EMER
  /// EXIT LT switch at ON, or automatically in ARM when the normal
  /// electrical supply is lost.
  bool get emerLights =>
      _emerLights ||
      _emerExitLt == EmerLtSwitch.on ||
      (_emerExitLt == EmerLtSwitch.arm && _normalPowerLost);

  /// The FAP controls the cabin lights through the CIDS directors.
  bool _lightsBlocked() {
    if (!cidsDown) return false;
    _showNotice(
      'CIDS 1+2 FAULT - NO CABIN LIGHT CONTROL',
      color: FapColors.red,
    );
    notifyListeners();
    return true;
  }

  static LightZone zoneOfClass(CabinClass c) => switch (c) {
    CabinClass.first => LightZone.first,
    CabinClass.business => LightZone.business,
    CabinClass.tourist => LightZone.tourist,
  };

  /// Lighting zones of the active layout, forward to aft.
  List<LightZone> get activeZones => [
    LightZone.fwdEntry,
    for (final c in activeLayout.classes) zoneOfClass(c),
    LightZone.aftEntry,
  ];

  /// True when any general cabin illumination zone is on.
  bool get mainLightsOn => activeZones.any((z) => _lights[z] != LightLevel.off);

  /// The level shared by every zone, or null when zones differ / are off.
  LightLevel? get generalLevel {
    final zones = activeZones;
    final first = _lights[zones.first]!;
    if (first == LightLevel.off) return null;
    return zones.every((z) => _lights[z] == first) ? first : null;
  }

  /// Pressing the selected level again switches that zone off (FAP toggle).
  void setZoneLight(LightZone z, LightLevel level) {
    if (_lightsBlocked()) return;
    _lights[z] = _lights[z] == level ? LightLevel.off : level;
    _changed();
  }

  void _setAllZones(LightLevel level) {
    for (final z in LightZone.values) {
      _lights[z] = level;
    }
  }

  void setGeneralLight(LightLevel level) {
    if (_lightsBlocked()) return;
    _setAllZones(generalLevel == level ? LightLevel.off : level);
    _changed();
  }

  /// LIGHTS MAIN ON/OFF (hard key and touch key).
  void toggleMainLights() {
    if (_lightsBlocked()) return;
    _setAllZones(mainLightsOn ? LightLevel.off : LightLevel.bright);
    _changed();
  }

  void toggleWindowLights() {
    if (_lightsBlocked()) return;
    _windowLights = !_windowLights;
    _changed();
  }

  void toggleAisleLights() {
    if (_lightsBlocked()) return;
    _aisleLights = !_aisleLights;
    _changed();
  }

  void toggleReadingAll() {
    if (_lightsBlocked()) return;
    _readingAll = !_readingAll;
    _changed();
  }

  /// R/L SET: switches on every passenger reading light (except inhibited
  /// seats); R/L RESET switches them all off.
  void readingLightsSet(bool on) {
    if (_lightsBlocked()) return;
    _readingAll = on;
    _changed();
  }

  void toggleAttWorkLights() {
    if (_lightsBlocked()) return;
    _attWorkLights = !_attWorkLights;
    _changed();
  }

  /// LAV MAINT hard key: lavatory lights full bright for maintenance.
  void toggleLavMaint() {
    if (_lightsBlocked()) return;
    _lavMaint = !_lavMaint;
    _changed();
  }

  /// EMER hard key: cabin emergency lighting on/off.
  void toggleEmerLights() {
    _emerLights = !_emerLights;
    _changed();
  }

  // ------------------------------------------------------------ doors

  static Map<DoorId, DoorStatus> _defaultDoors() => {
    for (final d in DoorId.values)
      d: d.isOverwing
          ? const DoorStatus(closed: true, armed: true)
          // Aircraft at the gate: L1 open for boarding, all disarmed.
          : DoorStatus(closed: d != DoorId.l1, armed: false),
  };

  final Map<DoorId, DoorStatus> _doors = _defaultDoors();

  DoorStatus door(DoorId id) => _doors[id]!;

  bool get allDoorsSecure => _doors.values.every((d) => d.isSecure);
  bool get anySlideDeployed => _doors.values.any((d) => d.slideDeployed);
  bool get allDoorsClosed => _doors.values.every((d) => d.closed);
  int get armedCount => _doors.values.where((d) => d.armed).length;
  int get closedCount => _doors.values.where((d) => d.closed).length;
  List<DoorId> get deployedDoors =>
      DoorId.values.where((d) => _doors[d]!.slideDeployed).toList();

  /// Trainer: moves the arming lever at the door.
  void toggleSlideArm(DoorId id) {
    final d = _doors[id]!;
    if (id.isOverwing) {
      _showNotice('${id.label}: OVERWING SLIDE IS PERMANENTLY ARMED');
    } else if (d.slideDeployed) {
      _showNotice(
        '${id.label}: SLIDE DEPLOYED - USE RESET DRILL',
        color: FapColors.red,
      );
    } else if (!d.closed) {
      _showNotice('${id.label}: CLOSE THE DOOR BEFORE ARMING');
    } else {
      _doors[id] = d.copyWith(armed: !d.armed);
    }
    _changed();
  }

  /// Trainer: opens or closes the door. Opening an armed door deploys
  /// its escape slide, exactly like the aircraft.
  void operateDoor(DoorId id) {
    final d = _doors[id]!;
    if (d.slideDeployed) {
      _showNotice(
        '${id.label}: SLIDE DEPLOYED - USE RESET DRILL',
        color: FapColors.red,
      );
    } else if (!d.closed) {
      _doors[id] = d.copyWith(closed: true);
    } else if (d.armed) {
      _doors[id] = d.copyWith(closed: false, slideDeployed: true);
      _showNotice(
        'SLIDE DEPLOYED AT ${id.label} - DOOR OPENED WHILE ARMED',
        color: FapColors.red,
      );
    } else {
      _doors[id] = d.copyWith(closed: false);
    }
    _changed();
  }

  /// Trainer: "Cabin crew, arm slides and cross-check".
  void armAllSlides() {
    final open = <String>[];
    for (final id in DoorId.values) {
      final d = _doors[id]!;
      if (d.slideDeployed) continue;
      if (!d.closed) {
        open.add(id.label);
      } else {
        _doors[id] = d.copyWith(armed: true);
      }
    }
    if (open.isNotEmpty) {
      _showNotice('NOT ARMED - DOOR OPEN: ${open.join(', ')}');
    }
    _changed();
  }

  /// Trainer: "Cabin crew, disarm slides and cross-check".
  void disarmAllSlides() {
    for (final id in DoorId.values) {
      final d = _doors[id]!;
      if (id.isOverwing || d.slideDeployed) continue;
      _doors[id] = d.copyWith(armed: false);
    }
    _changed();
  }

  void resetDoorsDrill() {
    _doors
      ..clear()
      ..addAll(_defaultDoors());
    _changed();
  }

  // ------------------------------------------------------------ audio / PRAM

  String _selectedPram = pramLibrary.first.id;
  String? _playingAnnouncement;
  double _paGain = 0.8;
  double _musicLevel = 0.6;

  String get selectedPram => _selectedPram;
  PramItem get selectedPramItem =>
      pramLibrary.firstWhere((p) => p.id == _selectedPram);
  String? get playingAnnouncement => _playingAnnouncement;
  PramItem? get onAnnounce => _playingAnnouncement == null
      ? null
      : pramLibrary.firstWhere((p) => p.id == _playingAnnouncement);
  double get paGain => _paGain;
  double get musicLevel => _musicLevel;

  void selectPram(String id) {
    _selectedPram = id;
    notifyListeners();
  }

  // MEMO: a queue of announcements for PLAY NEXT / PLAY ALL.
  final List<String> _memo = [];
  int _memoSel = 0;
  bool _playAll = false;
  List<String> get memo => List.unmodifiable(_memo);
  int get memoSelected => _memoSel;
  bool get playingAll => _playAll;

  /// Arrow right: copies the selected announcement into the MEMO list.
  void memoAdd() {
    _memo.add(_selectedPram);
    _memoSel = _memo.length - 1;
    notifyListeners();
  }

  /// Arrow left: removes the highlighted MEMO entry.
  void memoRemove() {
    if (_memo.isEmpty) return;
    _memo.removeAt(_memoSel);
    _memoSel = _memoSel.clamp(0, max(0, _memo.length - 1));
    notifyListeners();
  }

  void memoSelect(int i) {
    if (i < 0 || i >= _memo.length) return;
    _memoSel = i;
    notifyListeners();
  }

  void memoMove(int delta) => memoSelect(_memoSel + delta);

  void memoClear() {
    _memo.clear();
    _memoSel = 0;
    notifyListeners();
  }

  Future<void> _announce(String id) async {
    String? blocked;
    if (cidsDown) {
      blocked = 'CIDS 1+2 FAULT - PA NOT AVAILABLE';
    } else if (!pramAvailable) {
      blocked = 'NO PRAM CARD - USE THE HANDSET FOR ANNOUNCEMENTS';
    } else if (_cockpitPa) {
      blocked = 'COCKPIT PA HAS PRIORITY - PLAY AFTER THE COCKPIT PA';
    }
    if (blocked != null) {
      _showNotice(blocked, color: FapColors.red);
      _playAll = false;
      notifyListeners();
      return;
    }
    _playingAnnouncement = id;
    notifyListeners();
    final ok = await audio.announce(id, voice: pramCard!.voiceFolder);
    if (!ok) {
      _playingAnnouncement = null;
      _playAll = false;
      _showNotice('ANNOUNCEMENT COULD NOT BE PLAYED');
      notifyListeners();
    }
  }

  /// DIRECT PLAY: plays the selected announcement now (a new announcement
  /// always replaces the one playing; two never overlap).
  Future<void> playSelectedPram() => _announce(_selectedPram);

  /// PLAY NEXT: plays the first MEMO entry and removes it from the list.
  Future<void> playNext() async {
    if (_memo.isEmpty) {
      _playAll = false;
      _showNotice('MEMO IS EMPTY');
      notifyListeners();
      return;
    }
    final id = _memo.removeAt(0);
    _memoSel = 0;
    await _announce(id);
  }

  /// PLAY ALL: plays the whole MEMO list in order.
  Future<void> playAll() async {
    _playAll = true;
    await playNext();
  }

  /// STOP: stops the announcement (and PLAY ALL).
  Future<void> stopSelectedPram() async {
    _playAll = false;
    _playAllTimer?.cancel();
    if (_playingAnnouncement != null) await audio.stopAnnouncement();
    notifyListeners();
  }

  Future<void> stopAllAudio() async {
    _playAll = false;
    _playAllTimer?.cancel();
    _bgmOn = false;
    notifyListeners();
    await audio.stopMusic();
    await audio.stopAnnouncement();
  }

  void _onAnnouncementDone() {
    if (_playingAnnouncement == null) return;
    _playingAnnouncement = null;
    if (_playAll && _memo.isNotEmpty) {
      _playAllTimer?.cancel();
      _playAllTimer = Timer(const Duration(milliseconds: 700), () {
        if (!_disposed && _playAll) playNext();
      });
    } else {
      _playAll = false;
    }
    notifyListeners();
  }

  void setPaGain(double v) {
    _paGain = v;
    audio.setPaGain(v);
    _changed();
  }

  void setMusicLevel(double v) {
    _musicLevel = v;
    audio.setMusicLevel(v);
    _changed();
  }

  // Boarding music (BGM1): channel, ON/OFF, VOL and CHAN +/-.
  BgmChannel _bgmChannel = BgmChannel.blues;
  bool _bgmOn = false;
  BgmChannel get bgmChannel => _bgmChannel;
  bool get musicPlaying => _bgmOn;

  /// 0..10 volume steps shown on the BGM panel.
  int get bgmVolume => (_musicLevel * 10).round();

  void bgmSelect(BgmChannel c) {
    _bgmChannel = c;
    if (_bgmOn && !cidsDown && pramAvailable) audio.startMusic(c);
    _changed();
  }

  void bgmChannelStep(int delta) {
    final all = BgmChannel.values;
    bgmSelect(all[(_bgmChannel.index + delta) % all.length]);
  }

  void bgmToggle() {
    if (!_bgmOn && cidsDown) {
      _showNotice('CIDS 1+2 FAULT - BGM NOT AVAILABLE', color: FapColors.red);
      notifyListeners();
      return;
    }
    if (!_bgmOn && !pramAvailable) {
      _showNotice(
        'NO PRAM CARD - BOARDING MUSIC NOT AVAILABLE',
        color: FapColors.red,
      );
      notifyListeners();
      return;
    }
    _bgmOn = !_bgmOn;
    if (_bgmOn) {
      audio.startMusic(_bgmChannel);
    } else {
      audio.stopMusic();
    }
    notifyListeners();
  }

  void bgmVolumeStep(int delta) =>
      setMusicLevel(((bgmVolume + delta).clamp(0, 10)) / 10);

  bool _chimeInhibit = false;
  bool get chimeInhibit => _chimeInhibit;

  /// CHIME INHIB on the audio page: silences cabin chimes.
  void toggleChimeInhibit() {
    _chimeInhibit = !_chimeInhibit;
    _changed();
  }

  void playChime(ChimeType type) {
    if (_chimeInhibit) {
      _showNotice('CHIME INHIBITED - PRESS CHIME INHIB TO RESTORE');
      notifyListeners();
      return;
    }
    if (cidsDown) {
      _showNotice(
        'CIDS 1+2 FAULT - CHIMES NOT AVAILABLE',
        color: FapColors.red,
      );
      notifyListeners();
      return;
    }
    audio.chime(type);
  }

  // ------------------------------------------------------------ temperature

  /// Zone temperature selected by the flight crew (cockpit, 18-30 °C).
  final Map<TempZone, double> _cockpitTemp = {
    TempZone.fwd: 22.0,
    TempZone.aft: 22.0,
  };

  /// Cabin crew fine adjustment from the FAP (±2.5 °C).
  final Map<TempZone, double> _fapTrim = {TempZone.fwd: 0.0, TempZone.aft: 0.0};
  final Map<TempZone, double> _actualTemp = {
    TempZone.fwd: 24.0,
    TempZone.aft: 23.5,
  };

  double cockpitTemp(TempZone z) => _cockpitTemp[z]!;
  double fapTrim(TempZone z) => _fapTrim[z]!;
  double targetTemp(TempZone z) => (_cockpitTemp[z]! + _fapTrim[z]!)
      .clamp(FapConstants.minTemp, FapConstants.maxTemp)
      .toDouble();
  double actualTemp(TempZone z) => _actualTemp[z]!;
  double get cabinTemp =>
      _actualTemp.values.reduce((a, b) => a + b) / _actualTemp.length;

  /// FAP +/-: fine adjustment around the cockpit selection.
  void adjustTemp(TempZone z, double delta) {
    const limit = FapConstants.fapTempTrim;
    final next = (_fapTrim[z]! + delta).clamp(-limit, limit).toDouble();
    if (next == _fapTrim[z]) {
      _showNotice('FAP ADJUSTMENT LIMIT ±$limit°C - ASK THE FLIGHT CREW');
    }
    _fapTrim[z] = next;
    _changed();
  }

  /// RESET: back to the cockpit selected temperature in all areas.
  void resetTempToCockpit() {
    _fapTrim.updateAll((_, _) => 0.0);
    _showNotice(
      'RESET TO COCKPIT SELECTED TEMPERATURE',
      color: FapColors.okGreen,
    );
    _changed();
  }

  bool _tempF = false;
  bool get tempFahrenheit => _tempF;

  /// FAP CONFIG: temperature unit.
  void setTempUnit(bool fahrenheit) {
    _tempF = fahrenheit;
    _changed();
  }

  String formatTemp(double c, {int digits = 1}) => _tempF
      ? '${(c * 9 / 5 + 32).toStringAsFixed(digits)} °F'
      : '${c.toStringAsFixed(digits)} °C';

  /// Trainer: the flight crew changes the zone selector in the cockpit.
  void adjustCockpitTemp(TempZone z, double delta) {
    _cockpitTemp[z] = (_cockpitTemp[z]! + delta)
        .clamp(FapConstants.minTemp, FapConstants.maxTemp)
        .toDouble();
    _changed();
  }

  // ------------------------------------------------------------ water / waste

  double _waterPct = 80;
  double _wastePct = 25;
  int _waterPreselect = 100;

  double get waterPct => _waterPct;
  double get wastePct => _wastePct;
  int get waterPreselect => _waterPreselect;
  double get waterLitres => FapConstants.potableWaterLitres * _waterPct / 100;
  double get wasteLitres => FapConstants.wasteTankLitres * _wastePct / 100;
  bool get waterLow => _waterPct <= 20;
  bool get waterEmpty => _waterPct <= 0;
  bool get wasteFull => _wastePct >= 100;
  bool get wasteHigh => _wastePct >= 80;

  /// A full waste tank makes every vacuum toilet inoperative.
  bool get lavsInop => wasteFull;

  bool _warnAck = false;
  bool get _waterWarning => lavsInop || waterLow;

  /// RESET WARN: acknowledges the water / waste caution. It comes back if
  /// the condition clears and happens again.
  void resetWarn() {
    if (!_waterWarning) {
      _showNotice('NO WATER / WASTE WARNING', color: FapColors.textDim);
      notifyListeners();
      return;
    }
    _warnAck = true;
    _changed();
  }

  void _updateWarn() {
    if (!_waterWarning) _warnAck = false;
  }

  void setWaterPreselect(int pct) {
    _waterPreselect = pct;
    _changed();
  }

  void refillWater() {
    _waterPct = _waterPreselect.toDouble();
    _updateWarn();
    _changed();
  }

  void consumeWater() {
    _waterPct = (_waterPct - 10).clamp(0, 100).toDouble();
    _updateWarn();
    _changed();
  }

  void addWaste() {
    _wastePct = (_wastePct + 10).clamp(0, 100).toDouble();
    _updateWarn();
    _changed();
  }

  void drainWaste() {
    _wastePct = 0;
    _updateWarn();
    _changed();
  }

  // ------------------------------------------------------------ smoke

  final Map<Lavatory, LavSmokeStatus> _smoke = {
    for (final l in Lavatory.values) l: const LavSmokeStatus(),
  };

  LavSmokeStatus smoke(Lavatory l) => _smoke[l]!;
  bool get smokeAlarm => _smoke.values.any((s) => s.alert == SmokeAlert.alarm);
  bool get smokeMonitoring =>
      _smoke.values.any((s) => s.alert == SmokeAlert.reset);
  List<Lavatory> get smokeLavs => Lavatory.values
      .where((l) => _smoke[l]!.alert == SmokeAlert.alarm)
      .toList();

  /// Trainer: smoke appears in a lavatory.
  void triggerSmoke(Lavatory l) {
    _smoke[l] = const LavSmokeStatus(alert: SmokeAlert.alarm, source: true);
    _page = FapPage.smoke; // FAP pops the smoke page automatically.
    _updateAlarmSound();
    notifyListeners();
  }

  /// Trainer: the smoke has cleared. With no more smoke detected the CIDS
  /// resets all visual and aural indications automatically.
  void extinguishSmoke(Lavatory l) {
    _smoke[l] = const LavSmokeStatus();
    _updateAlarmSound();
    notifyListeners();
  }

  /// SMOKE RESET (hard key or touchscreen): silences the aural alert and
  /// the cabin indications. The FAP keeps showing the smoke for as long as
  /// the detector still senses it.
  void smokeReset() {
    var any = false;
    for (final l in Lavatory.values) {
      final s = _smoke[l]!;
      if (s.alert != SmokeAlert.alarm) continue;
      any = true;
      _smoke[l] = s.copyWith(alert: SmokeAlert.reset);
    }
    if (!any) _showNotice('NO ACTIVE SMOKE ALERT', color: FapColors.textDim);
    _updateAlarmSound();
    notifyListeners();
  }

  // ------------------------------------------------------------ evacuation

  bool _evacGuardOpen = false;
  bool _evacActive = false;

  bool _evacCaptOnly = false;

  bool get evacGuardOpen => _evacGuardOpen;
  bool get evacActive => _evacActive;

  /// Cockpit CAPT / CAPT & PURS selector. In CAPT, a cabin EVAC CMD only
  /// sounds the cockpit horn for 3 s; no cabin evacuation alert.
  bool get evacCaptOnly => _evacCaptOnly;

  /// Trainer: moves the cockpit CAPT / CAPT & PURS selector.
  void toggleEvacSelector() {
    _evacCaptOnly = !_evacCaptOnly;
    notifyListeners();
  }

  /// Trainer: the flight crew sets EVAC COMMAND ON in the cockpit.
  void cockpitEvacCommand() {
    _evacActive = true;
    _showNotice('EVAC COMMANDED FROM THE COCKPIT', color: FapColors.red);
    _updateAlarmSound();
    notifyListeners();
  }

  void toggleEvacGuard() {
    _evacGuardOpen = !_evacGuardOpen;
    notifyListeners();
  }

  /// EVAC CMD hard key (guarded).
  void evacCommand() {
    if (!_evacGuardOpen) {
      _showNotice('LIFT THE EVAC CMD GUARD FIRST');
      notifyListeners();
      return;
    }
    _evacGuardOpen = false;
    if (_evacCaptOnly) {
      _showNotice('SELECTOR IN CAPT: COCKPIT HORN ONLY (3 S) - NO CABIN EVAC');
      notifyListeners();
      return;
    }
    _evacActive = true;
    _updateAlarmSound();
    notifyListeners();
  }

  /// EVAC RESET hard key: silences the EVAC tone at this station and
  /// clears the EVAC indications.
  void evacReset() {
    if (!_evacActive) {
      _showNotice('NO EVAC COMMAND ACTIVE', color: FapColors.textDim);
      notifyListeners();
      return;
    }
    _evacActive = false;
    _updateAlarmSound();
    notifyListeners();
  }

  void _updateAlarmSound() {
    if (_evacActive) {
      audio.startEvacTone();
    } else if (smokeAlarm) {
      audio.startSmokeAlarm();
    } else {
      audio.stopAlarm();
    }
  }

  // ------------------------------------------------------------ other keys

  bool _paxSys = true;
  bool get paxSys => _paxSys;

  void togglePaxSys() {
    _paxSys = !_paxSys;
    _changed();
  }

  bool _pedPower = true;
  bool get pedPower => _pedPower;

  /// PED POWER hard key: passenger in-seat power supply on/off.
  void togglePedPower() {
    _pedPower = !_pedPower;
    _changed();
  }

  bool _fapRestarting = false;
  bool get fapRestarting => _fapRestarting;

  /// FAP-PC RESET hard key: restarts the FAP computer (screen only; the
  /// cabin systems keep their state).
  void fapReset() {
    if (_fapRestarting) return;
    _fapRestarting = true;
    _granted.clear();
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(seconds: 4), () {
      if (_disposed) return;
      _fapRestarting = false;
      notifyListeners();
    });
    notifyListeners();
  }

  // ------------------------------------------------------------ cockpit / aircraft

  FlightPhase _phase = FlightPhase.ground;
  FlightPhase get flightPhase => _phase;
  bool get onGround => _phase.onGround;

  /// Trainer: what the CIDS receives from the aircraft (ground / engines
  /// running / flight / approach with the gear down).
  void setFlightPhase(FlightPhase p) {
    if (p == _phase) return;
    final before = _signs;
    _phase = p;
    _afterSigns(before);
    _changed();
  }

  bool _seatBeltSw = false;
  SignSwitch _noSmokingSw = SignSwitch.auto;
  bool get seatBeltSwitch => _seatBeltSw;
  SignSwitch get noSmokingSwitch => _noSmokingSw;

  /// FASTEN SEAT BELT signs. They also come on by themselves at low cabin
  /// pressure, and are lost with CIDS 1+2 FAULT.
  bool get seatBeltSignOn => !cidsDown && (_seatBeltSw || _lowPressure);

  /// NO SMOKING signs: switch ON, or AUTO with the landing gear down.
  bool get noSmokingSignOn =>
      !cidsDown &&
      (_noSmokingSw == SignSwitch.on ||
          (_noSmokingSw == SignSwitch.auto && _phase.gearDown) ||
          _lowPressure);

  /// RETURN TO SEAT signs in the lavatories follow the seat belt signs.
  bool get returnToSeatOn => seatBeltSignOn;

  /// EXIT signs: with the emergency lights, at low cabin pressure, or in
  /// ARM when NO SMOKING is ON or AUTO with the gear down.
  bool get exitSignsOn =>
      emerLights ||
      _lowPressure ||
      (_emerExitLt == EmerLtSwitch.arm &&
          (_noSmokingSw == SignSwitch.on ||
              (_noSmokingSw == SignSwitch.auto && _phase.gearDown)));

  (bool, bool) get _signs => (seatBeltSignOn, noSmokingSignOn);

  /// A passenger sign switching on or off sounds a single low chime.
  void _afterSigns((bool, bool) before) {
    if (_signs != before && !cidsDown) audio.chime(ChimeType.singleLow);
  }

  /// Trainer: cockpit SEAT BELTS switch.
  void toggleSeatBeltSwitch() {
    final before = _signs;
    _seatBeltSw = !_seatBeltSw;
    _afterSigns(before);
    _changed();
  }

  /// Trainer: cockpit NO SMOKING switch.
  void setNoSmokingSwitch(SignSwitch s) {
    final before = _signs;
    _noSmokingSw = s;
    _afterSigns(before);
    _changed();
  }

  EmerLtSwitch _emerExitLt = EmerLtSwitch.arm;
  bool _normalPowerLost = false;
  EmerLtSwitch get emerExitLtSwitch => _emerExitLt;
  bool get normalPowerLost => _normalPowerLost;

  /// Trainer: cockpit EMER EXIT LT switch.
  void setEmerExitLt(EmerLtSwitch s) {
    _emerExitLt = s;
    _changed();
  }

  /// Trainer: the aircraft loses its normal electrical supply. In ARM the
  /// emergency lights come on by themselves.
  void toggleNormalPowerLost() {
    _normalPowerLost = !_normalPowerLost;
    if (_normalPowerLost && _emerExitLt == EmerLtSwitch.arm) {
      _showNotice(
        'NORMAL POWER LOST - EMERGENCY LIGHTS ON (AUTO)',
        color: FapColors.red,
      );
    }
    notifyListeners();
  }

  bool _lowPressure = false;
  bool get lowPressure => _lowPressure;

  /// Trainer: low cabin pressure. The CIDS switches every cabin light to
  /// BRT, the passenger signs come on and the PA volume goes up.
  void toggleLowCabinPressure() {
    final before = _signs;
    _lowPressure = !_lowPressure;
    audio.setPaBoost(_lowPressure);
    if (_lowPressure) {
      _setAllZones(LightLevel.bright);
      _showNotice(
        'LOW CABIN PRESSURE - LIGHTS BRT, SIGNS ON, PA LOUDER (AUTO)',
        color: FapColors.red,
      );
    } else {
      _showNotice('CABIN PRESSURE NORMAL', color: FapColors.okGreen);
    }
    _afterSigns(before);
    _changed();
  }

  bool _cockpitPa = false;
  bool get cockpitPa => _cockpitPa;

  /// Trainer: the flight crew makes a PA from the cockpit handset (the
  /// captain's voice plays). It has priority over the PRAM: a playing
  /// announcement stops and the boarding music is lowered until the cockpit
  /// PA ends, by itself when the captain finishes or with the key again.
  void toggleCockpitPa() {
    if (!_cockpitPa && cidsDown) {
      _showNotice('CIDS 1+2 FAULT - PA NOT AVAILABLE', color: FapColors.red);
      notifyListeners();
      return;
    }
    _cockpitPa = !_cockpitPa;
    audio.setOtherPaActive(_cockpitPa);
    if (_cockpitPa) {
      _playAll = false;
      _playAllTimer?.cancel();
      if (_playingAnnouncement != null) {
        audio.stopAnnouncement();
        _showNotice('COCKPIT PA - PRAM ANNOUNCEMENT STOPPED (PRIORITY)');
      }
      audio.startCockpitPa();
    } else {
      audio.stopCockpitPa();
    }
    notifyListeners();
  }

  void _onCockpitPaDone() {
    if (_disposed || !_cockpitPa) return;
    _cockpitPa = false;
    audio.setOtherPaActive(false);
    notifyListeners();
  }

  int _lockRemaining = 0;
  int get lockRemaining => _lockRemaining;
  bool get screenLocked => _lockRemaining > 0;

  /// SCREEN 30 SEC LOCK hard key: disables the touchscreen for cleaning.
  void screenLock() {
    _lockRemaining = FapConstants.screenLockSeconds;
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _lockRemaining--;
      if (_lockRemaining <= 0) {
        _lockRemaining = 0;
        t.cancel();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  // ------------------------------------------------------------ CAM layouts

  int _layoutId = 3;
  int? _pendingLayout;
  final Map<int, List<int>> _starts = {
    for (final l in cabinLayouts) l.id: [...l.defaultStarts],
  };
  final Map<int, int> _layoutCount = {for (final l in cabinLayouts) l.id: 0};
  final Map<int, DateTime> _layoutChanged = {};
  bool _nonSmoker = true;

  CabinLayout get activeLayout => layoutById(_layoutId);
  int get pendingLayout => _pendingLayout ?? _layoutId;

  /// The CAM whose layout is active (kept by the CIDS after a CAM change
  /// until a layout of the new CAM is loaded).
  Cartridge get activeCam => cardById(activeLayout.cam)!;

  /// Layouts of the CAM in the slot (empty without a CAM).
  List<CabinLayout> get slotLayouts {
    final cam = cardInSlot(CardSlot.cam);
    return cam == null ? const [] : layoutsOfCam(cam.id);
  }

  /// Why LAYOUT SELECTION cannot be used now (empty = available).
  List<String> get layoutSelectionBlocks => [
    if (!onGround) 'IN FLIGHT',
    if (cardInSlot(CardSlot.cam) == null) 'NO CAM IN SLOT',
  ];
  List<int> classStarts([int? id]) => _starts[id ?? _layoutId]!;
  int layoutCount(int id) => _layoutCount[id]!;
  DateTime? layoutChanged(int id) => _layoutChanged[id];
  bool get nonSmoker => _nonSmoker;

  /// First and last seat row of class number [i] of the active layout.
  (int, int) classRows(int i, [List<int>? starts]) {
    final st = starts ?? classStarts();
    final last = i + 1 < st.length ? st[i + 1] - 1 : activeLayout.rows;
    return (st[i], last);
  }

  CabinClass classOfRow(int row) {
    final st = classStarts();
    var c = 0;
    for (var i = 0; i < st.length; i++) {
      if (row >= st[i]) c = i;
    }
    return activeLayout.classes[c];
  }

  void selectLayoutRow(int id) {
    _pendingLayout = id;
    notifyListeners();
  }

  /// LOAD: activates the highlighted layout of the CAM in the slot
  /// (ground only).
  void loadLayout() {
    final blocks = layoutSelectionBlocks;
    if (blocks.isNotEmpty) {
      _showNotice(
        'LAYOUT SELECTION NOT AVAILABLE - ${blocks.join(' / ')}',
        color: FapColors.red,
      );
      notifyListeners();
      return;
    }
    if (!slotLayouts.any((l) => l.id == pendingLayout)) {
      _showNotice('SELECT A LAYOUT OF THE CAM IN THE SLOT');
      notifyListeners();
      return;
    }
    _layoutId = pendingLayout;
    _pendingLayout = null;
    _draftStarts = null;
    _applyAudioOutput();
    _showNotice(
      'LAYOUT ${activeLayout.number} LOADED (${activeCam.name})',
      color: FapColors.okGreen,
    );
    _changed();
  }

  // Cabin programming: edits a draft, SAVE writes it to the CAM.
  List<int>? _draftStarts;
  bool? _draftNonSmoker;
  int _boundary = 1;
  ({int layout, int count, DateTime date})? _saved;

  List<int> get draftStarts => _draftStarts ?? classStarts();
  bool get draftNonSmoker => _draftNonSmoker ?? _nonSmoker;
  int get selectedBoundary =>
      _boundary.clamp(1, max(1, draftStarts.length - 1));
  bool get programmingDirty => _draftStarts != null || _draftNonSmoker != null;
  ({int layout, int count, DateTime date})? get savedInfo => _saved;

  /// CABIN ZONE: picks the class boundary to move (1 = between the first
  /// and the second class).
  void selectBoundary(int i) {
    _boundary = i;
    notifyListeners();
  }

  /// Moves the selected class boundary by [delta] seat rows.
  void moveBoundary(int delta) {
    final st = [...draftStarts];
    final i = selectedBoundary;
    if (st.length < 2) {
      _showNotice('1-CLASS LAYOUT: NO CABIN ZONES TO MOVE');
      notifyListeners();
      return;
    }
    final lo = st[i - 1] + 1;
    final hi = i + 1 < st.length ? st[i + 1] - 1 : activeLayout.rows;
    final next = (st[i] + delta).clamp(lo, hi);
    if (next == st[i]) return;
    st[i] = next;
    _draftStarts = st;
    notifyListeners();
  }

  void toggleNonSmokerDraft() {
    _draftNonSmoker = !draftNonSmoker;
    notifyListeners();
  }

  /// SAVE: writes the cabin programming to the CAM (layout becomes
  /// "MODIFIED" and its change counter goes up).
  void saveProgramming() {
    if (!programmingDirty) {
      _showNotice('NOTHING TO SAVE', color: FapColors.textDim);
      notifyListeners();
      return;
    }
    // The modified layout is written to the CAM of the active layout.
    if (cardInSlot(CardSlot.cam)?.id != activeLayout.cam) {
      _showNotice(
        cardInSlot(CardSlot.cam) == null
            ? 'NO CAM IN SLOT - CANNOT SAVE'
            : 'CAM IN SLOT IS NOT THE CAM OF THE ACTIVE LAYOUT',
        color: FapColors.red,
      );
      notifyListeners();
      return;
    }
    if (_draftStarts != null) _starts[_layoutId] = _draftStarts!;
    if (_draftNonSmoker != null) _nonSmoker = _draftNonSmoker!;
    _draftStarts = null;
    _draftNonSmoker = null;
    _layoutCount[_layoutId] = _layoutCount[_layoutId]! + 1;
    _layoutChanged[_layoutId] = fapClockNow();
    _saved = (
      layout: _layoutId,
      count: _layoutCount[_layoutId]!,
      date: _layoutChanged[_layoutId]!,
    );
    _changed();
  }

  void dismissSaved() {
    _saved = null;
    notifyListeners();
  }

  // ------------------------------------------------------------ seats / calls

  final Set<String> _callInhibited = {};
  final Set<String> _readingInhibited = {};
  bool _seatReadingMode = false;
  bool _callInhibitAll = false;
  final List<String> _paxCalls = [];

  /// SEAT SETTINGS works on passenger calls or reading lights.
  bool get seatReadingMode => _seatReadingMode;
  Set<String> get inhibitedSeats =>
      _seatReadingMode ? _readingInhibited : _callInhibited;
  bool get callInhibitAll => _callInhibitAll;

  /// Seats whose reading light is inhibited (they stay off on R/L SET).
  int get readingInhibitedCount => _readingInhibited.length;
  List<String> get paxCalls => List.unmodifiable(_paxCalls);

  void setSeatMode(bool reading) {
    _seatReadingMode = reading;
    notifyListeners();
  }

  void inhibitSeat(String seat) {
    inhibitedSeats.add(seat);
    if (!_seatReadingMode) _paxCalls.remove(seat);
    _changed();
  }

  void enableSeat(String seat) {
    inhibitedSeats.remove(seat);
    _changed();
  }

  void enableAllSeats() {
    inhibitedSeats.clear();
    _changed();
  }

  /// CALL INHIBIT: ignores all passenger call buttons.
  void toggleCallInhibitAll() {
    _callInhibitAll = !_callInhibitAll;
    if (_callInhibitAll) _paxCalls.clear();
    _changed();
  }

  /// Trainer: a passenger presses a call button somewhere in the cabin.
  void simulatePaxCall() {
    if (_callInhibitAll) {
      _showNotice('PASSENGER CALLS INHIBITED');
      notifyListeners();
      return;
    }
    final free = [
      for (var r = 1; r <= activeLayout.rows; r++)
        for (final l in seatLetters)
          if (!_callInhibited.contains('$r$l') && !_paxCalls.contains('$r$l'))
            '$r$l',
    ];
    if (free.isEmpty) return;
    final seat = free[_random.nextInt(free.length)];
    _paxCalls.add(seat);
    if (!_chimeInhibit && !cidsDown) audio.chime(ChimeType.singleHigh);
    notifyListeners();
  }

  final Set<Lavatory> _lavCalls = {};

  /// Lavatories whose call button is pressed.
  List<Lavatory> get lavCalls =>
      Lavatory.values.where(_lavCalls.contains).toList();

  /// Seat and lavatory calls, as shown in the caution row.
  List<String> get allCalls => [
    ..._paxCalls,
    for (final l in lavCalls) l.label,
  ];

  /// Trainer: a passenger presses the call button in a lavatory (single
  /// high chime). Pressing it again cancels the call, like the aircraft.
  void lavCall(Lavatory l) {
    if (!_lavCalls.remove(l)) {
      _lavCalls.add(l);
      if (!_chimeInhibit && !cidsDown) audio.chime(ChimeType.singleHigh);
    }
    notifyListeners();
  }

  /// CALL RESET: cancels every passenger and lavatory call.
  void callReset() {
    if (_paxCalls.isEmpty && _lavCalls.isEmpty) {
      _showNotice('NO PASSENGER CALL', color: FapColors.textDim);
    }
    _paxCalls.clear();
    _lavCalls.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------ level adjust

  static List<String> levelAreasOf(LevelGroup g) => switch (g) {
    LevelGroup.cabinZones => [for (final c in CabinClass.values) c.label],
    LevelGroup.attendantAreas => ['FWD ATTENDANT', 'AFT ATTENDANT'],
    LevelGroup.lavatories => ['LAV A', 'LAV D', 'LAV E'],
  };

  final Map<String, LevelSetting> _levels = {
    for (final g in LevelGroup.values)
      for (final a in levelAreasOf(g)) a: const LevelSetting(),
  };
  LevelGroup _levelGroup = LevelGroup.cabinZones;
  int _levelSel = 0;

  LevelGroup get levelGroup => _levelGroup;
  int get levelSelected => _levelSel;
  LevelSetting level(String area) => _levels[area]!;

  /// Areas of the shown group (cabin zones follow the active layout).
  List<String> get levelAreas => _levelGroup == LevelGroup.cabinZones
      ? [for (final c in activeLayout.classes) c.label]
      : levelAreasOf(_levelGroup);

  void setLevelGroup(LevelGroup g) {
    _levelGroup = g;
    _levelSel = 0;
    notifyListeners();
  }

  void levelSelect(int i) {
    if (i < 0 || i >= levelAreas.length) return;
    _levelSel = i;
    notifyListeners();
  }

  void adjustLevel({int announce = 0, int chime = 0}) {
    final area = levelAreas[_levelSel];
    final l = _levels[area]!;
    int clampDb(int v) => v.clamp(SetupLimits.minDb, SetupLimits.maxDb);
    _levels[area] = LevelSetting(
      announce: clampDb(l.announce + announce),
      chime: clampDb(l.chime + chime),
    );
    _applyAudioOutput();
    _changed();
  }

  /// DEFAULT: all areas of the shown group back to +0 dB.
  void levelsDefault() {
    for (final a in levelAreasOf(_levelGroup)) {
      _levels[a] = const LevelSetting();
    }
    _applyAudioOutput();
    _changed();
  }

  void saveLevels() {
    _showNotice('LEVEL ADJUSTMENT SAVED', color: FapColors.okGreen);
    _changed();
  }

  // ------------------------------------------------------------ FAP set-up

  int _brightness = 100;
  int _loudspeaker = 100;
  int _headphone = 50;
  bool _touchClick = true;
  bool _muteAll = false;

  int get brightness => _brightness;
  int get loudspeaker => _loudspeaker;
  int get headphone => _headphone;
  bool get touchClick => _touchClick;
  bool get muteAll => _muteAll;

  void adjustBrightness(int delta) {
    _brightness = (_brightness + delta).clamp(20, 100);
    _changed();
  }

  void adjustLoudspeaker(int delta) {
    _loudspeaker = (_loudspeaker + delta).clamp(0, 100);
    _applyAudioOutput();
    _changed();
  }

  void adjustHeadphone(int delta) {
    _headphone = (_headphone + delta).clamp(0, 100);
    _changed();
  }

  void toggleTouchClick() {
    _touchClick = !_touchClick;
    _changed();
  }

  void setupDefault() {
    _brightness = 100;
    _loudspeaker = 100;
    _headphone = 50;
    _touchClick = true;
    _applyAudioOutput();
    _changed();
  }

  void saveSetup() {
    _showNotice('FAP SET-UP SAVED', color: FapColors.okGreen);
    _changed();
  }

  /// FAP CONFIG: mutes every sound of the simulator.
  void setMuteAll(bool mute) {
    _muteAll = mute;
    _applyAudioOutput();
    _changed();
  }

  /// Key click on every touchscreen key (when enabled).
  void keyClick() {
    if (_touchClick) audio.click();
  }

  void _applyAudioOutput() {
    double avg(int Function(LevelSetting) f) {
      final areas = [for (final c in activeLayout.classes) c.label];
      return areas.map((a) => f(_levels[a]!)).reduce((a, b) => a + b) /
          areas.length;
    }

    audio.setOutput(
      loudspeaker: _loudspeaker / 100,
      muted: _muteAll,
      announceDb: avg((l) => l.announce),
      chimeDb: avg((l) => l.chime),
    );
  }

  // ------------------------------------------------------------ software

  double? _swProgress;

  /// OBRM whose software the CIDS runs.
  String _activeSw = 'obrm_a';

  /// 0..1 while software is loading, otherwise null.
  double? get swProgress => _swProgress;

  Cartridge get activeSoftware => cardById(_activeSw)!;

  /// True when the CIDS runs the software of the OBRM in the slot.
  bool get swUpdated => cardInSlot(CardSlot.obrm)?.id == _activeSw;

  /// LOAD SW: loads the CIDS software from the OBRM; the CIDS restarts
  /// automatically afterwards.
  void loadSoftware() {
    if (_swProgress != null) return;
    final obrm = cardInSlot(CardSlot.obrm);
    if (obrm == null) {
      _showNotice('NO OBRM IN SLOT', color: FapColors.red);
      notifyListeners();
      return;
    }
    if (swUpdated) {
      _showNotice('SOFTWARE ALREADY UP TO DATE', color: FapColors.textDim);
      notifyListeners();
      return;
    }
    _swProgress = 0;
    _swTimer?.cancel();
    _swTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (_disposed) return t.cancel();
      _swProgress = _swProgress! + 0.02;
      if (_swProgress! >= 1) {
        t.cancel();
        _swProgress = null;
        _activeSw = obrm.id;
        fapReset();
        _changed();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  // ------------------------------------------------------------ cartridges

  final Map<CardSlot, String?> _slotCard = {...defaultCards};

  /// Slots emptied with REMOVE that still wait for OK.
  final Set<CardSlot> _slotPending = {};

  /// Card chosen in the trainer card case, per slot.
  final Map<CardSlot, String> _cardPick = {...defaultCards};

  /// The card physically in [slot] (also while waiting for OK).
  Cartridge? cardPhysicallyIn(CardSlot slot) => cardById(_slotCard[slot]);

  /// The card the CIDS can use: in the slot and confirmed with OK.
  Cartridge? cardInSlot(CardSlot slot) =>
      _slotPending.contains(slot) ? null : cardById(_slotCard[slot]);

  bool slotPending(CardSlot slot) => _slotPending.contains(slot);
  String cardPick(CardSlot slot) => _cardPick[slot]!;

  Cartridge? get pramCard => cardInSlot(CardSlot.pram);

  /// Announcements and boarding music need a PRAM card.
  bool get pramAvailable => pramCard != null;

  /// FAP SET-UP > REMOVE: the card can be taken out of [slot].
  void removeCard(CardSlot slot) {
    if (slot == CardSlot.obrm && _swProgress != null) {
      _showNotice(
        'SOFTWARE LOADING - DO NOT REMOVE THE OBRM',
        color: FapColors.red,
      );
      notifyListeners();
      return;
    }
    if (_slotCard[slot] == null) {
      _showNotice('${slot.label} SLOT IS EMPTY - INSERT A CARD, THEN PRESS OK');
      notifyListeners();
      return;
    }
    _slotCard[slot] = null;
    _slotPending.add(slot);
    if (slot == CardSlot.pram) {
      _playAll = false;
      _playAllTimer?.cancel();
      if (_playingAnnouncement != null) audio.stopAnnouncement();
      if (_bgmOn) {
        _bgmOn = false;
        audio.stopMusic();
      }
    }
    _showNotice('${slot.label} REMOVED - INSERT THE NEW CARD, THEN PRESS OK');
    _changed();
  }

  /// Trainer card case: chooses the card to insert into [slot].
  void pickCard(CardSlot slot, String id) {
    _cardPick[slot] = id;
    notifyListeners();
  }

  /// Trainer card case: puts the chosen card into the empty [slot].
  void insertCard(CardSlot slot) {
    if (_slotCard[slot] != null) {
      _showNotice('${slot.label} SLOT IS FULL - PRESS REMOVE ON THE FAP FIRST');
      notifyListeners();
      return;
    }
    _slotCard[slot] = _cardPick[slot];
    _slotPending.add(slot);
    _changed();
  }

  /// FAP SET-UP > OK: the card change of [slot] is finished.
  void confirmCard(CardSlot slot) {
    final card = cardPhysicallyIn(slot);
    if (card == null) {
      _showNotice('NO CARD IN THE ${slot.label} SLOT', color: FapColors.red);
      notifyListeners();
      return;
    }
    _slotPending.remove(slot);
    switch (slot) {
      case CardSlot.pram:
        _showNotice('PRAM LOADED - ${card.name}', color: FapColors.okGreen);
      case CardSlot.cam:
        _pendingLayout = null;
        _showNotice(
          card.id == activeLayout.cam
              ? 'CAM INSERTED - ${card.name}'
              : 'CAM INSERTED - LOAD A LAYOUT ON LAYOUT SELECTION',
          color: FapColors.okGreen,
        );
      case CardSlot.obrm:
        _showNotice(
          swUpdated
              ? 'OBRM INSERTED - SOFTWARE UP TO DATE'
              : 'OBRM INSERTED - LOAD THE SOFTWARE ON SOFTWARE LOADING',
          color: FapColors.okGreen,
        );
    }
    _changed();
  }

  // ------------------------------------------------------------ CIDS

  bool _dir1Fault = false;
  bool _dir2Fault = false;
  bool get dir1Fault => _dir1Fault;
  bool get dir2Fault => _dir2Fault;
  bool get cidsDown => _dir1Fault && _dir2Fault;

  /// 1 or 2, or null when both directors have failed.
  int? get activeDirector => !_dir1Fault ? 1 : (!_dir2Fault ? 2 : null);

  /// True once the cabin lights went to full brightness after the loss of
  /// the CIDS (until it is restored).
  bool _cidsLightsFull = false;
  bool get cidsLightsFull => _cidsLightsFull;

  void toggleDirectorFault(int n) {
    final wasDown = cidsDown;
    if (n == 1) {
      _dir1Fault = !_dir1Fault;
    } else {
      _dir2Fault = !_dir2Fault;
    }
    if (cidsDown && !wasDown) {
      // PA, interphone and passenger signs are lost.
      _bgmOn = false;
      _playAll = false;
      _cockpitPa = false;
      audio.setOtherPaActive(false);
      audio.stopCockpitPa();
      audio.stopMusic();
      audio.stopAnnouncement();
      // Without a CIDS signal the cabin lights go to full brightness
      // after 3 minutes.
      _cidsLightTimer?.cancel();
      _cidsLightTimer = Timer(const Duration(minutes: 3), () {
        if (_disposed || !cidsDown) return;
        _setAllZones(LightLevel.bright);
        _cidsLightsFull = true;
        _changed();
      });
    } else if (wasDown && !cidsDown) {
      // CIDS back: the lavatory lights dim, the others stay as they are.
      _cidsLightTimer?.cancel();
      _cidsLightsFull = false;
      _lavMaint = false;
    }
    _changed();
  }

  // ------------------------------------------------------------ status row

  CautionMessage get caution {
    if (_evacActive) {
      return const CautionMessage(
        'EVAC  -  EVACUATION COMMAND ACTIVE',
        FapColors.red,
        flashing: true,
      );
    }
    if (smokeAlarm) {
      return CautionMessage(
        'SMOKE  ${smokeLavs.map((l) => l.label).join(' / ')}',
        FapColors.red,
        flashing: true,
      );
    }
    if (cidsDown) {
      return const CautionMessage(
        'CIDS 1+2 FAULT - PA / INTERPHONE / SIGNS LOST',
        FapColors.red,
      );
    }
    if (anySlideDeployed) {
      return CautionMessage(
        'SLIDE DEPLOYED  ${deployedDoors.map((d) => d.label).join(' / ')}',
        FapColors.red,
      );
    }
    if (lavsInop && !_warnAck) {
      return const CautionMessage(
        'WASTE TANK FULL - LAVATORIES INOP',
        FapColors.amber,
      );
    }
    if (waterLow && !_warnAck) {
      return CautionMessage(
        waterEmpty ? 'POTABLE WATER EMPTY' : 'POTABLE WATER LOW',
        FapColors.amber,
      );
    }
    if (allCalls.isNotEmpty) {
      return CautionMessage(
        'PAX CALL  ${allCalls.join(' / ')}',
        FapColors.cyan,
      );
    }
    if (_dir1Fault || _dir2Fault) {
      return CautionMessage(
        'CIDS DIR ${_dir1Fault ? 1 : 2} FAULT',
        FapColors.amber,
      );
    }
    if (!allDoorsSecure) {
      return const CautionMessage(
        'Please check door/slide status prior departure',
        FapColors.cyan,
        flashing: true,
      );
    }
    return CautionMessage(
      _cabinReady
          ? 'ALL DOORS CLOSED  -  ALL SLIDES ARMED  -  CABIN READY'
          : 'ALL DOORS CLOSED  -  ALL SLIDES ARMED',
      FapColors.okGreen,
    );
  }

  // ------------------------------------------------------------ lifecycle

  void _onTick() {
    var moved = false;
    for (final z in TempZone.values) {
      final a = _actualTemp[z]!;
      final t = targetTemp(z);
      if (a == t) continue;
      final diff = t - a;
      _actualTemp[z] = diff.abs() <= 0.1 ? t : a + (diff > 0 ? 0.1 : -0.1);
      moved = true;
    }
    if (moved) notifyListeners();
  }

  /// Restores factory defaults (everything except audio levels).
  void resetSimulator() {
    for (final z in LightZone.values) {
      _lights[z] = LightLevel.bright;
    }
    _windowLights = true;
    _aisleLights = true;
    _readingAll = false;
    _attWorkLights = true;
    _lavMaint = false;
    _emerLights = false;
    _doors
      ..clear()
      ..addAll(_defaultDoors());
    _cockpitTemp.updateAll((_, _) => 22.0);
    _fapTrim.updateAll((_, _) => 0.0);
    _actualTemp[TempZone.fwd] = 24.0;
    _actualTemp[TempZone.aft] = 23.5;
    _waterPct = 80;
    _wastePct = 25;
    _waterPreselect = 100;
    _smoke.updateAll((_, _) => const LavSmokeStatus());
    _evacActive = false;
    _evacGuardOpen = false;
    _evacCaptOnly = false;
    _paxSys = true;
    _pedPower = true;
    _chimeInhibit = false;
    _dir1Fault = false;
    _dir2Fault = false;
    _bgmOn = false;
    _playAll = false;
    _memo.clear();
    _playingAnnouncement = null;
    _paxCalls.clear();
    _callInhibited.clear();
    _readingInhibited.clear();
    _callInhibitAll = false;
    _cabinReady = false;
    _warnAck = false;
    _layoutId = 3;
    _pendingLayout = null;
    _draftStarts = null;
    _draftNonSmoker = null;
    for (final l in cabinLayouts) {
      _starts[l.id] = [...l.defaultStarts];
      _layoutCount[l.id] = 0;
    }
    _layoutChanged.clear();
    _nonSmoker = true;
    _levels.updateAll((_, _) => const LevelSetting());
    _granted.clear();
    _lavCalls.clear();
    _phase = FlightPhase.ground;
    _seatBeltSw = false;
    _noSmokingSw = SignSwitch.auto;
    _emerExitLt = EmerLtSwitch.arm;
    _normalPowerLost = false;
    _lowPressure = false;
    audio.setPaBoost(false);
    _cockpitPa = false;
    audio.setOtherPaActive(false);
    audio.stopCockpitPa();
    _cidsLightTimer?.cancel();
    _cidsLightsFull = false;
    _slotCard
      ..clear()
      ..addAll(defaultCards);
    _cardPick
      ..clear()
      ..addAll(defaultCards);
    _slotPending.clear();
    _activeSw = 'obrm_a';
    _swTimer?.cancel();
    _swProgress = null;
    _applyAudioOutput();
    audio.stopAll();
    _page = FapPage.lights;
    _showNotice('SIMULATOR RESET TO DEFAULTS', color: FapColors.okGreen);
    _changed();
  }

  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_prefsKey);
      if (raw == null) return;
      _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      audio.setPaGain(_paGain);
      audio.setMusicLevel(_musicLevel);
      _applyAudioOutput();
      notifyListeners();
    } catch (e) {
      debugPrint('FapProvider: could not restore state: $e');
    }
  }

  Future<void> _save() async {
    if (_disposed) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_prefsKey, jsonEncode(_toJson()));
    } catch (e) {
      debugPrint('FapProvider: could not save state: $e');
    }
  }

  Map<String, dynamic> _toJson() => {
    'lights': {for (final e in _lights.entries) e.key.name: e.value.name},
    'window': _windowLights,
    'reading': _readingAll,
    'att': _attWorkLights,
    'lavMaint': _lavMaint,
    'emer': _emerLights,
    'doors': {for (final e in _doors.entries) e.key.name: e.value.toJson()},
    'paGain': _paGain,
    'musicLevel': _musicLevel,
    'cockpitTemp': {for (final e in _cockpitTemp.entries) e.key.name: e.value},
    'fapTrim': {for (final e in _fapTrim.entries) e.key.name: e.value},
    'actualTemp': {for (final e in _actualTemp.entries) e.key.name: e.value},
    'water': _waterPct,
    'waste': _wastePct,
    'preselect': _waterPreselect,
    'paxSys': _paxSys,
    'aisle': _aisleLights,
    'bgmChannel': _bgmChannel.name,
    'memo': _memo,
    'cabinReady': _cabinReady,
    'layout': _layoutId,
    'starts': {for (final e in _starts.entries) '${e.key}': e.value},
    'layoutCount': {for (final e in _layoutCount.entries) '${e.key}': e.value},
    'layoutChanged': {
      for (final e in _layoutChanged.entries)
        '${e.key}': e.value.toIso8601String(),
    },
    'nonSmoker': _nonSmoker,
    'callInhibited': _callInhibited.toList(),
    'readingInhibited': _readingInhibited.toList(),
    'callInhibitAll': _callInhibitAll,
    'levels': {
      for (final e in _levels.entries) e.key: [e.value.announce, e.value.chime],
    },
    'brightness': _brightness,
    'loudspeaker': _loudspeaker,
    'headphone': _headphone,
    'touchClick': _touchClick,
    'muteAll': _muteAll,
    'tempF': _tempF,
    'showTrainer': _showTrainer,
    'activeSw': _activeSw,
    'pedPower': _pedPower,
    'chimeInhibit': _chimeInhibit,
    'phase': _phase.name,
    'seatBeltSw': _seatBeltSw,
    'noSmokingSw': _noSmokingSw.name,
    'emerExitLt': _emerExitLt.name,
    'cards': {for (final e in _slotCard.entries) e.key.name: e.value},
    'cardsPending': [for (final s in _slotPending) s.name],
  };

  void _fromJson(Map<String, dynamic> j) {
    T? byName<T extends Enum>(List<T> values, Object? name) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    final lights = j['lights'] as Map<String, dynamic>? ?? {};
    for (final e in lights.entries) {
      final z = byName(LightZone.values, e.key);
      final l = byName(LightLevel.values, e.value);
      if (z != null && l != null) _lights[z] = l;
    }
    _windowLights = j['window'] as bool? ?? _windowLights;
    _readingAll = j['reading'] as bool? ?? _readingAll;
    _attWorkLights = j['att'] as bool? ?? _attWorkLights;
    _lavMaint = j['lavMaint'] as bool? ?? _lavMaint;
    _emerLights = j['emer'] as bool? ?? _emerLights;

    final doors = j['doors'] as Map<String, dynamic>? ?? {};
    for (final e in doors.entries) {
      final id = byName(DoorId.values, e.key);
      if (id == null) continue;
      var s = DoorStatus.fromJson(e.value as Map<String, dynamic>);
      if (id.isOverwing) s = s.copyWith(armed: true);
      _doors[id] = s;
    }

    _paGain = (j['paGain'] as num?)?.toDouble() ?? _paGain;
    _musicLevel = (j['musicLevel'] as num?)?.toDouble() ?? _musicLevel;

    void temps(String key, Map<TempZone, double> into, double lo, double hi) {
      final m = j[key] as Map<String, dynamic>? ?? {};
      for (final e in m.entries) {
        final z = byName(TempZone.values, e.key);
        if (z != null && e.value is num) {
          into[z] = (e.value as num).toDouble().clamp(lo, hi);
        }
      }
    }

    const minT = FapConstants.minTemp, maxT = FapConstants.maxTemp;
    const trim = FapConstants.fapTempTrim;
    temps('cockpitTemp', _cockpitTemp, minT, maxT);
    temps('fapTrim', _fapTrim, -trim, trim);
    temps('actualTemp', _actualTemp, minT, maxT);
    _waterPct = ((j['water'] as num?)?.toDouble() ?? _waterPct)
        .clamp(0, 100)
        .toDouble();
    _wastePct = ((j['waste'] as num?)?.toDouble() ?? _wastePct)
        .clamp(0, 100)
        .toDouble();
    final pre = j['preselect'] as int?;
    if (pre != null && FapConstants.waterPreselect.contains(pre)) {
      _waterPreselect = pre;
    }
    _paxSys = j['paxSys'] as bool? ?? _paxSys;
    _aisleLights = j['aisle'] as bool? ?? _aisleLights;
    _bgmChannel = byName(BgmChannel.values, j['bgmChannel']) ?? _bgmChannel;
    final pramIds = {for (final p in pramLibrary) p.id};
    _memo
      ..clear()
      ..addAll([
        for (final m in (j['memo'] as List? ?? const []))
          if (pramIds.contains(m)) m as String,
      ]);
    _cabinReady = j['cabinReady'] as bool? ?? _cabinReady;
    final lid = j['layout'] as int?;
    if (lid != null && cabinLayouts.any((l) => l.id == lid)) _layoutId = lid;
    final starts = j['starts'] as Map<String, dynamic>? ?? {};
    for (final l in cabinLayouts) {
      final v = starts['${l.id}'];
      if (v is List && v.length == l.classes.length) {
        final st = [for (final x in v) (x as num).toInt()];
        var ok = st.first == 1 && st.last <= l.rows;
        for (var i = 1; i < st.length; i++) {
          if (st[i] <= st[i - 1]) ok = false;
        }
        if (ok) _starts[l.id] = st;
      }
    }
    final counts = j['layoutCount'] as Map<String, dynamic>? ?? {};
    for (final l in cabinLayouts) {
      final c = counts['${l.id}'];
      if (c is int && c >= 0) _layoutCount[l.id] = c;
    }
    final changed = j['layoutChanged'] as Map<String, dynamic>? ?? {};
    for (final e in changed.entries) {
      final d = DateTime.tryParse('${e.value}');
      final id = int.tryParse(e.key);
      if (d != null && id != null) _layoutChanged[id] = d;
    }
    _nonSmoker = j['nonSmoker'] as bool? ?? _nonSmoker;
    _callInhibited
      ..clear()
      ..addAll([
        for (final x in (j['callInhibited'] as List? ?? const [])) '$x',
      ]);
    _readingInhibited
      ..clear()
      ..addAll([
        for (final x in (j['readingInhibited'] as List? ?? const [])) '$x',
      ]);
    _callInhibitAll = j['callInhibitAll'] as bool? ?? _callInhibitAll;
    final levels = j['levels'] as Map<String, dynamic>? ?? {};
    for (final e in levels.entries) {
      final v = e.value;
      if (_levels.containsKey(e.key) && v is List && v.length == 2) {
        int c(Object? x) => ((x as num?)?.toInt() ?? 0).clamp(
          SetupLimits.minDb,
          SetupLimits.maxDb,
        );
        _levels[e.key] = LevelSetting(announce: c(v[0]), chime: c(v[1]));
      }
    }
    _brightness = ((j['brightness'] as int?) ?? _brightness).clamp(20, 100);
    _loudspeaker = ((j['loudspeaker'] as int?) ?? _loudspeaker).clamp(0, 100);
    _headphone = ((j['headphone'] as int?) ?? _headphone).clamp(0, 100);
    _touchClick = j['touchClick'] as bool? ?? _touchClick;
    _muteAll = j['muteAll'] as bool? ?? _muteAll;
    _tempF = j['tempF'] as bool? ?? _tempF;
    _showTrainer = j['showTrainer'] as bool? ?? _showTrainer;
    final sw = j['activeSw'];
    if (obrmSoftware.containsKey(sw)) {
      _activeSw = sw as String;
    } else if (j['swUpdated'] == true) {
      _activeSw = 'obrm_b'; // saved by v3.x
    }
    _pedPower = j['pedPower'] as bool? ?? _pedPower;
    _chimeInhibit = j['chimeInhibit'] as bool? ?? _chimeInhibit;
    _phase = byName(FlightPhase.values, j['phase']) ?? _phase;
    _seatBeltSw = j['seatBeltSw'] as bool? ?? _seatBeltSw;
    _noSmokingSw = byName(SignSwitch.values, j['noSmokingSw']) ?? _noSmokingSw;
    _emerExitLt = byName(EmerLtSwitch.values, j['emerExitLt']) ?? _emerExitLt;
    final cards = j['cards'];
    if (cards is Map<String, dynamic>) {
      for (final slot in CardSlot.values) {
        if (!cards.containsKey(slot.name)) continue;
        final id = cards[slot.name];
        if (id == null) {
          _slotCard[slot] = null;
        } else if (cardsFor(slot).any((c) => c.id == id)) {
          _slotCard[slot] = id as String;
        }
      }
    }
    _slotPending
      ..clear()
      ..addAll([
        for (final s in (j['cardsPending'] as List? ?? const []))
          ?byName(CardSlot.values, s),
      ]);
    // An empty slot always waits for a card and OK.
    for (final slot in CardSlot.values) {
      if (_slotCard[slot] == null) _slotPending.add(slot);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _tick.cancel();
    _saveTimer?.cancel();
    _noticeTimer?.cancel();
    _lockTimer?.cancel();
    _restartTimer?.cancel();
    _swTimer?.cancel();
    _playAllTimer?.cancel();
    _cidsLightTimer?.cancel();
    audio.dispose();
    super.dispose();
  }
}
