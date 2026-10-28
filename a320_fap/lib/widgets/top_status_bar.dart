import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fap_state.dart';
import '../providers/fap_provider.dart';
import '../theme/fap_theme.dart';
import 'blink.dart';
import 'fap_button.dart';

/// FAP header: CAUT key, system badge, caution/info row, cabin temperature
/// and UTC. CAUT flashes while an event page has not been looked at, and
/// stays lit once every event page has been selected; the info row then
/// asks for the page of the new event.
class TopStatusBar extends StatelessWidget {
  const TopStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    final blink = context.watch<Blink>().value;
    final caution = fap.caution;
    final textColor = caution.flashing && !blink
        ? caution.color.withValues(alpha: 0.3)
        : caution.color;
    final caut = fap.cautState;
    final info = fap.infoPage;

    return Container(
      height: 42,
      color: FapColors.statusBar,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          FapButton(
            label: 'CAUT',
            width: 64,
            height: 30,
            fontSize: 11,
            tone: caut == CautState.off
                ? FapButtonTone.normal
                : FapButtonTone.amber,
            flashing: caut == CautState.flashing,
            onTap: caut == CautState.off ? null : fap.cautPressed,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FapColors.inactive,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: FapColors.inactiveHighlight),
            ),
            child: Text(
              'FAP 1',
              style: FapText.monoStyle(size: 13, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: const Color(0xFF050B11),
                border: Border.all(color: caution.color.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                caution.text,
                overflow: TextOverflow.ellipsis,
                style: FapText.monoStyle(
                  size: 14,
                  color: textColor,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (info != null) ...[
            const SizedBox(width: 8),
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: blink ? FapColors.amber : const Color(0xFF050B11),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: FapColors.amber),
              ),
              child: Text(
                'SELECT ${info.tabLabel.replaceAll('\n', ' ')} PAGE',
                style: FapText.monoStyle(
                  size: 13,
                  color: blink ? Colors.black : FapColors.amber,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(width: 16),
          const Icon(Icons.thermostat, color: FapColors.cyan, size: 18),
          Text(
            fap.formatTemp(fap.cabinTemp, digits: 0).replaceAll(' ', ''),
            style: FapText.monoStyle(
              size: 15,
              color: FapColors.cyan,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 18),
          const _UtcClock(),
        ],
      ),
    );
  }
}

/// Time source for the header clock; tests replace it with a fixed time.
DateTime Function() fapClockNow = DateTime.now;

class _UtcClock extends StatefulWidget {
  const _UtcClock();

  @override
  State<_UtcClock> createState() => _UtcClockState();
}

class _UtcClockState extends State<_UtcClock> {
  late Timer _timer;
  DateTime _now = fapClockNow().toUtc();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = fapClockNow().toUtc());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');
    return Text(
      '${two(_now.hour)}:${two(_now.minute)}:${two(_now.second)} UTC',
      style: FapText.monoStyle(size: 15, weight: FontWeight.w700),
    );
  }
}
