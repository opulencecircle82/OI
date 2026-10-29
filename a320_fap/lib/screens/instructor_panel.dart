import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cabin_setup.dart';
import '../models/cartridge.dart';
import '../models/fap_state.dart';
import '../providers/fap_provider.dart';
import '../services/fap_audio.dart';
import '../theme/fap_theme.dart';
import '../widgets/fap_button.dart';

/// INSTRUCTOR panel: everything that happens away from the FAP (cockpit,
/// passengers, doors, aircraft, maintenance) and the simulator settings.
/// It opens from the INSTRUCTOR key on the panel frame and covers the right
/// side of the panel; nothing of it is part of the real A320 FAP.
class InstructorPanel extends StatelessWidget {
  const InstructorPanel({super.key});

  static const width = 590.0;

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    final tab = fap.instructorTab;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF15111F),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(10),
          ),
          border: Border.all(color: FapColors.instructor, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0xCC000000), blurRadius: 24),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: FapColors.instructor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INSTRUCTOR PANEL',
                        style: TextStyle(
                          color: FapColors.instructor,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Not part of the A320 FAP: events away from the panel.',
                        style: FapText.label,
                      ),
                    ],
                  ),
                ),
                FapButton(
                  label: '',
                  icon: Icons.close,
                  width: 48,
                  height: 38,
                  onTap: fap.toggleInstructor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final t in InstructorTab.values) ...[
                  Expanded(
                    child: FapButton(
                      label: t.label,
                      width: double.infinity,
                      height: 38,
                      fontSize: 11,
                      active: tab == t,
                      onTap: () => fap.setInstructorTab(t),
                    ),
                  ),
                  if (t != InstructorTab.values.last) const SizedBox(width: 5),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: switch (tab) {
                  InstructorTab.cockpit => _Cockpit(fap: fap),
                  InstructorTab.cabin => _Cabin(fap: fap),
                  InstructorTab.doors => _Doors(fap: fap),
                  InstructorTab.aircraft => _Aircraft(fap: fap),
                  InstructorTab.maint => _Maintenance(fap: fap),
                  InstructorTab.simulator => _Simulator(fap: fap),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ parts

/// Titled group of instructor controls.
class _Group extends StatelessWidget {
  const _Group(this.title, {required this.children, this.note});
  final String title;
  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: FapColors.instructor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: FapText.label.copyWith(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

Widget _key(
  String label,
  VoidCallback onTap, {
  bool active = false,
  bool enabled = true,
  double width = 100,
  double height = 40,
  FapButtonTone tone = FapButtonTone.normal,
}) => FapButton(
  label: label,
  width: width,
  height: height,
  fontSize: 11,
  active: active,
  enabled: enabled,
  tone: tone,
  onTap: onTap,
);

Widget _row(List<Widget> keys) =>
    Wrap(spacing: 6, runSpacing: 6, children: keys);

// ------------------------------------------------------------------ tabs

class _Cockpit extends StatelessWidget {
  const _Cockpit({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    Widget temp(TempZone z) => Row(
      children: [
        SizedBox(width: 92, child: Text(z.label, style: FapText.label)),
        _key(
          '-',
          () => fap.adjustCockpitTemp(z, -FapConstants.tempStep),
          enabled: fap.cockpitTemp(z) > FapConstants.minTemp,
          width: 52,
        ),
        SizedBox(
          width: 96,
          child: Text(
            fap.formatTemp(fap.cockpitTemp(z)),
            textAlign: TextAlign.center,
            style: FapText.monoStyle(size: 15, weight: FontWeight.w700),
          ),
        ),
        _key(
          '+',
          () => fap.adjustCockpitTemp(z, FapConstants.tempStep),
          enabled: fap.cockpitTemp(z) < FapConstants.maxTemp,
          width: 52,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(
          'FLIGHT PHASE',
          children: [
            _row([
              for (final p in FlightPhase.values)
                _key(
                  p.label,
                  () => fap.setFlightPhase(p),
                  active: fap.flightPhase == p,
                  width: 128,
                ),
            ]),
          ],
        ),
        _Group(
          'SIGNS PANEL (OVERHEAD)',
          children: [
            Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text('SEAT BELTS', style: FapText.label),
                ),
                _key(
                  fap.seatBeltSwitch ? 'ON' : 'OFF',
                  fap.toggleSeatBeltSwitch,
                  active: fap.seatBeltSwitch,
                  width: 80,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text('NO SMOKING', style: FapText.label),
                ),
                _row([
                  for (final s in SignSwitch.values)
                    _key(
                      s.label,
                      () => fap.setNoSmokingSwitch(s),
                      active: fap.noSmokingSwitch == s,
                      width: 80,
                    ),
                ]),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text('EMER EXIT LT', style: FapText.label),
                ),
                _row([
                  for (final s in EmerLtSwitch.values)
                    _key(
                      s.label,
                      () => fap.setEmerExitLt(s),
                      active: fap.emerExitLtSwitch == s,
                      width: 80,
                    ),
                ]),
              ],
            ),
          ],
        ),
        _Group(
          'COCKPIT PA',
          note: 'The captain speaks; it has priority over the PRAM.',
          children: [
            _key(
              'COCKPIT\nPA',
              fap.toggleCockpitPa,
              active: fap.cockpitPa,
              width: 128,
              height: 44,
            ),
          ],
        ),
        _Group(
          'ZONE TEMPERATURE SELECTORS',
          note: 'Flight crew selection, 18-30 °C.',
          children: [
            for (final z in TempZone.values) ...[
              temp(z),
              const SizedBox(height: 6),
            ],
          ],
        ),
        _Group(
          'EVACUATION',
          children: [
            _row([
              _key(
                fap.evacCaptOnly ? 'SELECTOR\nCAPT' : 'SELECTOR\nCAPT & PURS',
                fap.toggleEvacSelector,
                active: fap.evacCaptOnly,
                width: 150,
                height: 44,
              ),
              _key(
                'COCKPIT\nEVAC CMD',
                fap.cockpitEvacCommand,
                width: 150,
                height: 44,
              ),
            ]),
          ],
        ),
      ],
    );
  }
}

class _Cabin extends StatelessWidget {
  const _Cabin({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(
          'LAVATORY CALL BUTTON',
          children: [
            _row([
              for (final l in Lavatory.values)
                _key(
                  l.label,
                  () => fap.lavCall(l),
                  active: fap.lavCalls.contains(l),
                  width: 120,
                ),
            ]),
          ],
        ),
        _Group(
          'PASSENGER SEAT CALL',
          note: fap.paxCalls.isEmpty
              ? 'No active call.'
              : 'ACTIVE: ${fap.paxCalls.join(', ')}',
          children: [
            _key(
              'PASSENGER\nPRESSES CALL',
              fap.simulatePaxCall,
              width: 180,
              height: 46,
            ),
          ],
        ),
        _Group(
          'LAVATORY SMOKE',
          children: [
            for (final l in Lavatory.values) ...[
              Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(l.label, style: FapText.label),
                  ),
                  _key(
                    'SMOKE',
                    () => fap.triggerSmoke(l),
                    enabled: !fap.smoke(l).source,
                    width: 110,
                  ),
                  const SizedBox(width: 6),
                  _key(
                    'EXTINGUISH',
                    () => fap.extinguishSmoke(l),
                    enabled: fap.smoke(l).source,
                    width: 120,
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ],
    );
  }
}

class _Doors extends StatelessWidget {
  const _Doors({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    Widget door(DoorId id) {
      final d = fap.door(id);
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(width: 92, child: Text(id.label, style: FapText.label)),
            _key(
              id.isOverwing ? 'AUTO ARM' : (d.armed ? 'DISARM' : 'ARM'),
              () => fap.toggleSlideArm(id),
              enabled: !id.isOverwing && !d.slideDeployed,
              width: 100,
              height: 34,
            ),
            const SizedBox(width: 6),
            _key(
              d.closed ? 'OPEN' : 'CLOSE',
              () => fap.operateDoor(id),
              enabled: !d.slideDeployed,
              width: 100,
              height: 34,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(
          'AT THE DOOR: ARMING LEVER AND HANDLE',
          children: [for (final id in DoorId.values) door(id)],
        ),
        _Group(
          'CABIN CREW COMMANDS',
          children: [
            _row([
              _key(
                'ARM SLIDES\nX-CHECK',
                fap.armAllSlides,
                width: 150,
                height: 44,
              ),
              _key(
                'DISARM SLIDES\nX-CHECK',
                fap.disarmAllSlides,
                width: 150,
                height: 44,
              ),
              _key(
                'RESET DRILL',
                fap.resetDoorsDrill,
                width: 150,
                height: 44,
                tone: fap.anySlideDeployed
                    ? FapButtonTone.amber
                    : FapButtonTone.normal,
              ),
            ]),
          ],
        ),
      ],
    );
  }
}

class _Aircraft extends StatelessWidget {
  const _Aircraft({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(
          'ELECTRICAL / PRESSURE',
          children: [
            _row([
              _key(
                'NORMAL\nPOWER LOST',
                fap.toggleNormalPowerLost,
                active: fap.normalPowerLost,
                width: 150,
                height: 44,
              ),
              _key(
                'LOW CABIN\nPRESSURE',
                fap.toggleLowCabinPressure,
                active: fap.lowPressure,
                width: 150,
                height: 44,
              ),
            ]),
          ],
        ),
        _Group(
          'CIDS FAULTS',
          note: 'Both directors failed = CIDS 1+2 FAULT.',
          children: [
            _row([
              _key(
                'DIR 1\nFAULT',
                () => fap.toggleDirectorFault(1),
                active: fap.dir1Fault,
                width: 150,
                height: 44,
              ),
              _key(
                'DIR 2\nFAULT',
                () => fap.toggleDirectorFault(2),
                active: fap.dir2Fault,
                width: 150,
                height: 44,
              ),
            ]),
          ],
        ),
        _Group(
          'WATER / WASTE (FLIGHT AND GROUND SERVICE)',
          children: [
            _row([
              _key('USE WATER\n-10%', fap.consumeWater, width: 125, height: 44),
              _key('REFILL\nWATER', fap.refillWater, width: 125, height: 44),
              _key('ADD WASTE\n+10%', fap.addWaste, width: 125, height: 44),
              _key('DRAIN\nWASTE', fap.drainWaste, width: 125, height: 44),
            ]),
          ],
        ),
      ],
    );
  }
}

class _Maintenance extends StatelessWidget {
  const _Maintenance({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    Widget row(CardSlot slot) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 50, child: Text(slot.label, style: FapText.label)),
          Expanded(
            child: _row([
              for (final c in cardsFor(slot))
                FapButton(
                  label: c.shortName,
                  width: 80,
                  height: 40,
                  fontSize: 10,
                  active: fap.cardPick(slot) == c.id,
                  onTap: () => fap.pickCard(slot, c.id),
                ),
            ]),
          ),
          _key(
            'INSERT',
            () => fap.insertCard(slot),
            enabled: fap.cardPhysicallyIn(slot) == null,
            width: 76,
          ),
        ],
      ),
    );

    return _Group(
      'CARD CASE (MAINTENANCE / AIRLINE TASK)',
      note:
          'On FAP SET-UP: REMOVE the card, INSERT the new one here, then '
          'press OK on the FAP.',
      children: [
        for (final s in CardSlot.values) row(s),
        const SizedBox(height: 4),
        for (final s in CardSlot.values)
          Builder(
            builder: (_) {
              final c = cardById(fap.cardPick(s))!;
              return Text(
                '${s.label}: ${c.partNumber}  -  ${c.contents}',
                overflow: TextOverflow.ellipsis,
                style: FapText.label.copyWith(fontSize: 11),
              );
            },
          ),
      ],
    );
  }
}

class _Simulator extends StatelessWidget {
  const _Simulator({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    Widget chime(String label, String meaning, ChimeType type) => Column(
      children: [
        _key(
          label,
          () => fap.playChime(type),
          enabled: !fap.cidsDown,
          width: 125,
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 125,
          child: Text(
            meaning,
            textAlign: TextAlign.center,
            style: FapText.label.copyWith(fontSize: 10),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(
          'CABIN CHIMES (LISTEN)',
          children: [
            _row([
              chime('HIGH', 'Passenger call', ChimeType.singleHigh),
              chime('HIGH-LOW', 'Crew call', ChimeType.highLow),
              chime('LOW', 'Seat belt / NS', ChimeType.singleLow),
              chime('EMER CALL', 'Cockpit (3x)', ChimeType.emergency),
            ]),
          ],
        ),
        _Group(
          'TEMPERATURE UNIT / SOUND',
          children: [
            _row([
              _key(
                'CELSIUS',
                () => fap.setTempUnit(false),
                active: !fap.tempFahrenheit,
                width: 125,
              ),
              _key(
                'FAHRENHEIT',
                () => fap.setTempUnit(true),
                active: fap.tempFahrenheit,
                width: 125,
              ),
              _key(
                'MUTE',
                () => fap.setMuteAll(!fap.muteAll),
                active: fap.muteAll,
                width: 125,
              ),
            ]),
          ],
        ),
        _Group(
          'ACCESS CODES (CIDS DEFAULTS)',
          children: [
            Text(
              '${SetupLimits.programmingCode} - Cabin Prog, Layout Select, '
              'Level Adjust\n'
              '${SetupLimits.softwareCode} - SW Load\n'
              'Access is kept until FAP RESET.',
              style: FapText.body.copyWith(fontSize: 13, height: 1.5),
            ),
          ],
        ),
        _Group(
          'RESET',
          note:
              'Every system back to its starting state, for the next trainee.',
          children: [
            _key(
              'RESET SIMULATOR',
              () => _confirmReset(context, fap),
              width: 200,
              height: 46,
              tone: FapButtonTone.amber,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context, FapProvider fap) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FapColors.panel,
        title: const Text('Reset simulator?', style: FapText.panelTitle),
        content: const Text(
          'All lights, doors, temperatures, water/waste levels and faults '
          'return to their starting state.',
          style: FapText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'RESET',
              style: TextStyle(color: FapColors.amber),
            ),
          ),
        ],
      ),
    );
    if (ok == true) fap.resetSimulator();
  }
}
