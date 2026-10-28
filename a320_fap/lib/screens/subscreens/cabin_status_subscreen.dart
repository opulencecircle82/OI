import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/fap_button.dart';

/// CABIN STATUS page: one overview tile per system; tap a tile to open
/// that system's page. The trainer box below simulates what happens away
/// from the FAP: the flight phase, the cockpit sign and emergency light
/// switches, a cockpit PA and lavatory calls.
class CabinStatusSubscreen extends StatelessWidget {
  const CabinStatusSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();

    final doorsColor = fap.anySlideDeployed
        ? FapColors.red
        : (fap.allDoorsSecure ? FapColors.okGreen : FapColors.amber);
    final smokeColor = fap.smokeAlarm
        ? FapColors.red
        : (fap.smokeMonitoring ? FapColors.amber : FapColors.okGreen);
    final waterColor = fap.wasteFull || fap.waterEmpty
        ? FapColors.red
        : (fap.waterLow || fap.wasteHigh ? FapColors.amber : FapColors.okGreen);
    final cidsColor = fap.cidsDown
        ? FapColors.red
        : (fap.dir1Fault || fap.dir2Fault
              ? FapColors.amber
              : FapColors.okGreen);
    final general = fap.generalLevel;
    String onOff(bool on) => on ? 'ON' : 'OFF';

    final tiles = <_Tile>[
      _Tile(
        page: FapPage.doors,
        icon: Icons.sensor_door_outlined,
        color: doorsColor,
        lines: [
          'CLOSED ${fap.closedCount}/${DoorId.values.length}',
          'ARMED  ${fap.armedCount}/${DoorId.values.length}',
          if (fap.anySlideDeployed) 'SLIDE DEPLOYED',
        ],
      ),
      _Tile(
        page: FapPage.lights,
        icon: Icons.lightbulb_outline,
        color: fap.mainLightsOn ? FapColors.gold : FapColors.textDim,
        lines: [
          'MAIN ${onOff(fap.mainLightsOn)}',
          'GENERAL ${general?.label ?? (fap.mainLightsOn ? 'MIXED' : 'OFF')}',
          if (fap.emerLights) 'EMER LT ON',
        ],
      ),
      _Tile(
        page: FapPage.audio,
        icon: Icons.campaign_outlined,
        color: fap.cidsDown ? FapColors.red : FapColors.cyan,
        lines: [
          if (fap.pramAvailable)
            'MUSIC ${onOff(fap.musicPlaying)}'
          else
            'NO PRAM CARD',
          if (fap.cockpitPa)
            'PA COCKPIT'
          else
            'PA ${fap.playingAnnouncement != null ? 'ON AIR' : 'IDLE'}',
        ],
      ),
      _Tile(
        page: FapPage.temperature,
        icon: Icons.thermostat,
        color: FapColors.cyan,
        lines: [
          for (final z in TempZone.values)
            '${z.name.toUpperCase()} ${fap.formatTemp(fap.actualTemp(z)).replaceAll(' ', '')}',
        ],
      ),
      _Tile(
        page: FapPage.water,
        icon: Icons.water_drop_outlined,
        color: waterColor,
        lines: [
          'WATER ${fap.waterPct.round()}%',
          'WASTE ${fap.wastePct.round()}%',
          if (fap.lavsInop) 'LAVS INOP',
        ],
      ),
      _Tile(
        page: FapPage.smoke,
        icon: Icons.smoke_free,
        color: smokeColor,
        lines: [
          fap.smokeAlarm
              ? 'SMOKE ${fap.smokeLavs.map((l) => l.label).join(' ')}'
              : (fap.smokeMonitoring ? 'MONITORING' : 'NORMAL'),
        ],
      ),
      _Tile(
        page: FapPage.systemInfo,
        icon: Icons.memory,
        color: cidsColor,
        lines: [
          fap.cidsDown ? 'CIDS 1+2 FAULT' : 'DIR ${fap.activeDirector} ACTIVE',
          'PAX SYS ${onOff(fap.paxSys)}',
        ],
      ),
      _Tile(
        page: null,
        icon: Icons.emergency_outlined,
        color: fap.evacActive ? FapColors.red : FapColors.okGreen,
        title: 'EVAC',
        lines: [fap.evacActive ? 'EVAC CMD ACTIVE' : 'NORMAL'],
      ),
      _Tile(
        page: null,
        icon: Icons.airline_seat_recline_normal,
        color: fap.cidsDown
            ? FapColors.red
            : (fap.lowPressure ? FapColors.amber : FapColors.white),
        title: 'PASSENGER SIGNS',
        lines: fap.cidsDown
            ? ['SIGNS LOST']
            : [
                'SEAT BELT ${onOff(fap.seatBeltSignOn)}',
                'NO SMOKING ${onOff(fap.noSmokingSignOn)}',
                'EXIT ${onOff(fap.exitSignsOn)}',
              ],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                const cols = 5, gap = 14.0;
                // 0.5 px less so rounding never pushes a tile to a new row.
                final w = (c.maxWidth - gap * (cols - 1)) / cols - 0.5;
                final h = (c.maxHeight - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final t in tiles)
                      SizedBox(
                        width: w,
                        height: h,
                        child: _TileView(tile: t, fap: fap),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _CockpitTrainer(fap: fap),
        ],
      ),
    );
  }
}

class _Tile {
  const _Tile({
    required this.page,
    required this.icon,
    required this.color,
    required this.lines,
    this.title,
  });

  final FapPage? page;
  final IconData icon;
  final Color color;
  final List<String> lines;
  final String? title;
}

class _TileView extends StatelessWidget {
  const _TileView({required this.tile, required this.fap});
  final _Tile tile;
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    final title = tile.title ?? tile.page!.title;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tile.page == null ? null : () => fap.goTo(tile.page!),
        borderRadius: BorderRadius.circular(6),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FapColors.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: tile.color.withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(tile.icon, color: tile.color, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: FapText.panelTitle,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              for (final l in tile.lines)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    l,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FapText.monoStyle(
                      size: 16,
                      color: tile.color,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Instructor controls for events away from the FAP.
class _CockpitTrainer extends StatelessWidget {
  const _CockpitTrainer({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    Widget key(
      String label,
      VoidCallback onTap, {
      bool active = false,
      double width = 78,
    }) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FapButton(
        label: label,
        width: width,
        height: 40,
        fontSize: 10.5,
        active: active,
        onTap: onTap,
      ),
    );

    Widget caption(String text, {double width = 86}) => SizedBox(
      width: width,
      child: Text(text, style: FapText.label.copyWith(fontSize: 11)),
    );

    const sep = SizedBox(width: 18);

    return TrainerBox(
      label: 'TRAINER  -  COCKPIT / AIRCRAFT / PASSENGERS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              caption('FLIGHT\nPHASE', width: 58),
              for (final p in FlightPhase.values)
                key(
                  p.label,
                  () => fap.setFlightPhase(p),
                  active: fap.flightPhase == p,
                  width: 96,
                ),
              sep,
              caption('SEAT BELTS', width: 76),
              key(
                fap.seatBeltSwitch ? 'ON' : 'OFF',
                fap.toggleSeatBeltSwitch,
                active: fap.seatBeltSwitch,
                width: 64,
              ),
              sep,
              caption('NO SMOKING', width: 80),
              for (final s in SignSwitch.values)
                key(
                  s.label,
                  () => fap.setNoSmokingSwitch(s),
                  active: fap.noSmokingSwitch == s,
                  width: 60,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              caption('EMER EXIT\nLT', width: 58),
              for (final s in EmerLtSwitch.values)
                key(
                  s.label,
                  () => fap.setEmerExitLt(s),
                  active: fap.emerExitLtSwitch == s,
                  width: 60,
                ),
              key(
                'NORMAL\nPOWER LOST',
                fap.toggleNormalPowerLost,
                active: fap.normalPowerLost,
                width: 104,
              ),
              sep,
              key(
                'COCKPIT\nPA',
                fap.toggleCockpitPa,
                active: fap.cockpitPa,
                width: 90,
              ),
              sep,
              caption('PASSENGER\nLAV CALL', width: 80),
              for (final l in Lavatory.values)
                key(
                  l.label,
                  () => fap.lavCall(l),
                  active: fap.lavCalls.contains(l),
                  width: 70,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
