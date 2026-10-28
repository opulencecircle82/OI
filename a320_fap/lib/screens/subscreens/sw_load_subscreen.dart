import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cartridge.dart';
import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/access_keypad.dart';
import '../../widgets/fap_button.dart';

/// SOFTWARE LOADING (access code): CIDS component software, active versus
/// the version on the OBRM in the slot. Amber = a different version is
/// waiting to be loaded; green = up to date. LOAD SW loads it and the CIDS
/// restarts automatically.
class SwLoadSubscreen extends StatelessWidget {
  const SwLoadSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    if (!fap.accessGranted(FapPage.swLoad)) {
      return const AccessKeypad(page: FapPage.swLoad);
    }
    final updated = fap.swUpdated;
    final slot = fap.cardInSlot(CardSlot.obrm);
    final act = obrmSoftware[fap.activeSoftware.id]!;
    final inSlot = slot == null ? null : obrmSoftware[slot.id]!;

    final components = [
      for (final n in [1, 2])
        (
          'DIRECTOR $n (${fap.activeDirector == n ? 'ACT.' : 'PAS.'})',
          'PNR: Z014H010035C   SER: ${n == 1 ? 5057 : 5055}   FIN: 10${n}RH',
          [
            ('MAINBOARD', act.mainboard, inSlot?.mainboard),
            ('DIB', act.dib, inSlot?.dib),
            ('SDF', act.sdf, inSlot?.sdf),
          ],
        ),
      (
        'FAP',
        'PNR: Z145H0052120   SER: 5011   FIN: 120RH',
        [('MAINBOARD', act.fap, inSlot?.fap)],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FapPanel(
              title: 'CIDS COMPONENTS',
              titleColor: FapColors.cyan,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(flex: 5, child: SizedBox()),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'OBRM ACTIVE  ${fap.activeSoftware.partNumber}',
                          style: FapText.label,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'IN SLOT  ${slot?.partNumber ?? 'NONE'}',
                          style: FapText.label,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final (name, ids, parts) in components)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13212E),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: FapColors.panelBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: FapText.panelTitle),
                                const SizedBox(height: 4),
                                Text(
                                  ids,
                                  style: FapText.label.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 10,
                            child: Column(
                              children: [
                                for (final (part, act, newV) in parts)
                                  Builder(
                                    builder: (_) {
                                      final c = newV == null
                                          ? FapColors.textDim
                                          : (act == newV
                                                ? FapColors.okGreen
                                                : FapColors.amber);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 1,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                part,
                                                style: FapText.monoStyle(
                                                  size: 12,
                                                  color: c,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 4,
                                              child: Text(
                                                act,
                                                style: FapText.monoStyle(
                                                  size: 12,
                                                  color: c,
                                                  weight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 4,
                                              child: Text(
                                                newV ?? '-',
                                                style: FapText.monoStyle(
                                                  size: 12,
                                                  color: c,
                                                  weight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const _Legend(FapColors.amber, 'NEW VERSION IN SLOT'),
                      const SizedBox(width: 20),
                      const _Legend(FapColors.okGreen, 'UP TO DATE'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  slot == null
                      ? 'No OBRM in the slot. Insert one on FAP SET-UP.'
                      : (updated
                            ? 'All components run the software of the OBRM '
                                  'in the slot.'
                            : 'Press LOAD SW to load the software from the '
                                  'OBRM. The CIDS restarts when loading is '
                                  'completed.'),
                  style: FapText.label,
                ),
                const SizedBox(height: 12),
                FapButton(
                  label: 'LOAD SW',
                  width: double.infinity,
                  height: 56,
                  tone: slot == null || updated
                      ? FapButtonTone.normal
                      : FapButtonTone.amber,
                  onTap: fap.loadSoftware,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.text);
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 14, height: 14, color: color),
      const SizedBox(width: 6),
      Text(text, style: FapText.label.copyWith(fontSize: 11)),
    ],
  );
}
