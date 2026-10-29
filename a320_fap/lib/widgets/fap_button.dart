import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/fap_provider.dart';
import '../theme/fap_theme.dart';
import 'blink.dart';

enum FapButtonTone { normal, amber, red }

/// Beveled CIDS touchscreen key. Grey when available, green when selected,
/// amber/red for caution/alarm (optionally flashing).
class FapButton extends StatelessWidget {
  const FapButton({
    super.key,
    required this.label,
    required this.onTap,
    this.active = false,
    this.enabled = true,
    this.tone = FapButtonTone.normal,
    this.flashing = false,
    this.width = 84,
    this.height = 46,
    this.fontSize = 13,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool enabled;
  final FapButtonTone tone;
  final bool flashing;
  final double width;
  final double height;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final blinkOn = flashing ? context.watch<Blink>().value : true;
    final usable = enabled && onTap != null;

    Color face;
    Color text;
    if (!usable) {
      face = FapColors.disabled;
      text = FapColors.disabledText;
    } else if (tone == FapButtonTone.red && blinkOn) {
      face = FapColors.red;
      text = FapColors.white;
    } else if (tone == FapButtonTone.amber && blinkOn) {
      face = FapColors.amber;
      text = Colors.black;
    } else if (active) {
      face = FapColors.activeGreen;
      text = Colors.black;
    } else {
      face = FapColors.inactive;
      text = FapColors.white;
    }

    final lit = face != FapColors.inactive && face != FapColors.disabled;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: usable
              ? () {
                  _keyClick(context);
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(4),
          splashColor: FapColors.white.withValues(alpha: 0.25),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(face, Colors.white, lit ? 0.18 : 0.10)!,
                  face,
                  Color.lerp(face, Colors.black, 0.25)!,
                ],
                stops: const [0, 0.45, 1],
              ),
              // A rounded box needs a uniform border; the bevel comes from
              // the gradient plus the drop shadow.
              border: Border.all(
                color: usable
                    ? Color.lerp(face, Colors.white, 0.35)!
                    : FapColors.inactiveShadow,
                width: 1.2,
              ),
              boxShadow: [
                const BoxShadow(
                  color: FapColors.inactiveShadow,
                  offset: Offset(1.5, 2.5),
                ),
                if (lit)
                  BoxShadow(
                    color: face.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
              ],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: icon != null
                    ? Icon(icon, color: text, size: fontSize + 9)
                    : Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          color: text,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          height: 1.1,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Touchscreen click (FAP SET-UP); silently skipped outside the app tree.
void _keyClick(BuildContext context) {
  try {
    context.read<FapProvider>().keyClick();
  } catch (_) {}
}

/// Slate CIDS container panel with a title strip.
class FapPanel extends StatelessWidget {
  const FapPanel({
    super.key,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.titleColor = FapColors.white,
    this.trailing,
    this.borderColor = FapColors.panelBorder,
  });

  final String title;
  final Widget child;
  final EdgeInsets padding;
  final Color titleColor;
  final Widget? trailing;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FapColors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              color: FapColors.panelTitle,
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: FapText.panelTitle.copyWith(color: titleColor),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Small monospaced status read-out (e.g. "ARMED", "CLOSED").
class StatusTag extends StatelessWidget {
  const StatusTag(
    this.text,
    this.color, {
    super.key,
    this.flashing = false,
    this.size = 12,
    this.filled = false,
  });

  final String text;
  final Color color;
  final bool flashing;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final on = flashing ? context.watch<Blink>().value : true;
    final c = on ? color : color.withValues(alpha: 0.25);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? c : Colors.transparent,
        border: Border.all(color: c, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: FapText.monoStyle(
          size: size,
          color: filled ? Colors.black : c,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}
