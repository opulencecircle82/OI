import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cartridge.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/fap_button.dart';

/// FAP SET-UP: display brightness, loudspeaker and headphone volume, the
/// touchscreen key click, and the PRAM / CAM / OBRM cartridges. A card is
/// changed with REMOVE, the new card is inserted (trainer card case), and
/// OK finishes the change.
class FapSetupSubscreen extends StatelessWidget {
  const FapSetupSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();

    Widget setting(
      String title,
      int value,
      void Function(int) step, {
      int min = 0,
    }) {
      return Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: FapText.panelTitle),
          const SizedBox(height: 8),
          Container(
            width: 100,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF050B11),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: FapColors.cyan),
            ),
            child: Text(
              '$value%',
              style: FapText.monoStyle(
                size: 18,
                color: FapColors.cyan,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // level bar
              Container(
                width: 22,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF050B11),
                  border: Border.all(color: FapColors.panelBorder),
                ),
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: value / 100,
                  child: Container(color: FapColors.cyan),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  FapButton(
                    label: '+',
                    icon: Icons.add,
                    width: 64,
                    height: 46,
                    enabled: value < 100,
                    onTap: () => step(10),
                  ),
                  const SizedBox(height: 8),
                  FapButton(
                    label: '-',
                    icon: Icons.remove,
                    width: 64,
                    height: 46,
                    enabled: value > min,
                    onTap: () => step(-10),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 250,
                child: FapPanel(
                  title: 'DISPLAY',
                  titleColor: FapColors.cyan,
                  child: setting(
                    'BRIGHTNESS',
                    fap.brightness,
                    fap.adjustBrightness,
                    min: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 440,
                child: FapPanel(
                  title: 'VOLUME',
                  titleColor: FapColors.cyan,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      setting(
                        'LOUDSPEAKER',
                        fap.loudspeaker,
                        fap.adjustLoudspeaker,
                      ),
                      setting('HEADPHONE', fap.headphone, fap.adjustHeadphone),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 220,
                child: FapPanel(
                  title: 'TOUCHSCREEN CLICK',
                  titleColor: FapColors.cyan,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      FapButton(
                        label: 'ON/OFF',
                        width: 120,
                        height: 50,
                        active: fap.touchClick,
                        onTap: fap.toggleTouchClick,
                      ),
                      const SizedBox(height: 96),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Column(
                children: [
                  const SizedBox(height: 120),
                  FapButton(
                    label: 'DEFAULT',
                    width: 170,
                    height: 50,
                    onTap: fap.setupDefault,
                  ),
                  const SizedBox(height: 10),
                  FapButton(
                    label: 'SAVE',
                    width: 170,
                    height: 50,
                    onTap: fap.saveSetup,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 560, child: _CartridgePanel(fap: fap)),
                const SizedBox(width: 16),
                Expanded(child: _CardCase(fap: fap)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The FAP side of a card change: what is in each slot, REMOVE and OK.
class _CartridgePanel extends StatelessWidget {
  const _CartridgePanel({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    Widget row(CardSlot slot) {
      final card = fap.cardPhysicallyIn(slot);
      final pending = fap.slotPending(slot);
      final (String status, Color color) = card == null
          ? ('EMPTY', FapColors.amber)
          : (pending
                ? ('PRESS OK', FapColors.amber)
                : ('IN SLOT', FapColors.okGreen));
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(slot.label, style: FapText.panelTitle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card?.name ?? '- NO CARD -',
                    overflow: TextOverflow.ellipsis,
                    style: FapText.monoStyle(
                      size: 13,
                      color: card == null ? FapColors.textDim : FapColors.white,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    card?.partNumber ?? '',
                    style: FapText.label.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 92,
              child: StatusTag(
                status,
                color,
                flashing: pending && card != null,
              ),
            ),
            FapButton(
              label: 'REMOVE',
              width: 92,
              height: 42,
              fontSize: 12,
              enabled: card != null,
              onTap: () => fap.removeCard(slot),
            ),
            const SizedBox(width: 8),
            FapButton(
              label: 'OK',
              width: 64,
              height: 42,
              fontSize: 12,
              tone: pending && card != null
                  ? FapButtonTone.amber
                  : FapButtonTone.normal,
              enabled: pending,
              onTap: () => fap.confirmCard(slot),
            ),
          ],
        ),
      );
    }

    return FapPanel(
      title: 'CARTRIDGES',
      titleColor: FapColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in CardSlot.values) row(s),
          const Text(
            '1. REMOVE   2. Insert the new card   3. OK.  '
            'After a CAM or OBRM change, load it on LAYOUT SELECTION or '
            'SOFTWARE LOADING.',
            style: FapText.label,
          ),
        ],
      ),
    );
  }
}

/// Trainer card case: the cards the maintenance / airline staff can put
/// into the slots.
class _CardCase extends StatelessWidget {
  const _CardCase({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    Widget row(CardSlot slot) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 50, child: Text(slot.label, style: FapText.label)),
          for (final c in cardsFor(slot))
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: FapButton(
                label: c.shortName,
                width: 84,
                height: 40,
                fontSize: 10,
                active: fap.cardPick(slot) == c.id,
                onTap: () => fap.pickCard(slot, c.id),
              ),
            ),
          const Spacer(),
          FapButton(
            label: 'INSERT',
            width: 76,
            height: 40,
            fontSize: 11,
            enabled: fap.cardPhysicallyIn(slot) == null,
            onTap: () => fap.insertCard(slot),
          ),
        ],
      ),
    );

    return TrainerBox(
      label: 'TRAINER  -  CARD CASE (MAINTENANCE / AIRLINE TASK)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in CardSlot.values) row(s),
          const SizedBox(height: 2),
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
      ),
    );
  }
}
