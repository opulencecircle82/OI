import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/fap_provider.dart';
import '../services/access_lock.dart';
import '../services/update_service.dart';
import '../theme/fap_theme.dart';
import 'update_dialog.dart';

/// SETTINGS key: license status of this device, app version and the
/// update check. The license code is not shown and the license cannot be
/// moved from here (the administrator releases it for a new device).
Future<void> showSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: _SettingsCard(onClose: () => Navigator.of(dialogContext).pop()),
      ),
    ),
  );
}

class _SettingsCard extends StatefulWidget {
  const _SettingsCard({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  String? _device;
  DateTime? _since;
  String? _info; // shown when the server could not be reached
  bool _checking = false;
  String? _updateMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final device = await AccessLock.deviceId();
    if (!mounted) return;
    setState(() => _device = device);
    final info = await AccessLock.licenseInfo();
    if (!mounted) return;
    setState(() {
      if (info.result == LicenseResult.ok) {
        _since = info.usedAt;
      } else if (info.result == LicenseResult.offline) {
        _info = 'Offline: connect to the internet to check the license.';
      } else if (info.result == LicenseResult.invalid) {
        _info = 'The server has no license for this device.';
      } else {
        _info = 'Could not reach the license server.';
      }
    });
  }

  Future<void> _checkUpdates() async {
    setState(() {
      _checking = true;
      _updateMessage = null;
    });
    final result = await UpdateService.checkNow();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _updateMessage = switch (result.status) {
        UpdateStatus.available => null,
        UpdateStatus.upToDate =>
          'You have the latest version (${AppConfig.version}).',
        UpdateStatus.unavailable =>
          'Could not check for updates. Connect to the internet and try '
              'again.',
      };
    });
    final info = result.info;
    if (info != null) {
      // This dialog closes; the update dialog opens on the navigator.
      final navContext = Navigator.of(context).context;
      widget.onClose();
      if (navContext.mounted) await showUpdateDialog(navContext, info);
    }
  }

  Widget _row(String label, String value, {bool copy = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FapText.label),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: FapText.monoStyle(size: 14, weight: FontWeight.w700),
              ),
            ),
            if (copy)
              IconButton(
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.copy,
                  size: 18,
                  color: FapColors.textDim,
                ),
                onPressed: () => Clipboard.setData(ClipboardData(text: value)),
              ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final since = _since;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Container(
        padding: const EdgeInsets.fromLTRB(26, 18, 18, 24),
        decoration: BoxDecoration(
          color: FapColors.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FapColors.panelBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: FapColors.cyan),
                const SizedBox(width: 10),
                const Expanded(child: Text('SETTINGS', style: FapText.title)),
                IconButton(
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: FapColors.textDim),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row('LICENSE', 'ACTIVE ON THIS DEVICE'),
                  if (since != null)
                    _row(
                      'ACTIVATED',
                      '${since.year}-${_two(since.month)}-${_two(since.day)} '
                          '${_two(since.hour)}:${_two(since.minute)}',
                    ),
                  _row('DEVICE ID', _device ?? '...', copy: _device != null),
                  _row('APP VERSION', AppConfig.version),
                  const _TrainerSwitch(),
                  if (_info != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_info!, style: FapText.label),
                    ),
                  const Text(
                    'New tablet or PC? Ask your instructor or administrator '
                    'to move the license.',
                    style: FapText.label,
                  ),
                  if (UpdateService.supported) ...[
                    const Divider(color: FapColors.panelBorder, height: 28),
                    OutlinedButton.icon(
                      onPressed: _checking ? null : _checkUpdates,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FapColors.cyan,
                        side: const BorderSide(color: FapColors.cyan),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Icon(Icons.system_update),
                      label: const Text(
                        'CHECK FOR UPDATES',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (_updateMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(_updateMessage!, style: FapText.label),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TRAINER CONTROLS: SHOW (practice) or HIDE (only the real A320 FAP on
/// screen, e.g. for an assessment).
class _TrainerSwitch extends StatelessWidget {
  const _TrainerSwitch();

  @override
  Widget build(BuildContext context) {
    final show = context.select<FapProvider, bool>((f) => f.showTrainer);
    final fap = context.read<FapProvider>();
    Widget choice(String label, bool value) {
      final on = show == value;
      return Expanded(
        child: OutlinedButton(
          onPressed: on ? null : () => fap.setShowTrainer(value),
          style: OutlinedButton.styleFrom(
            backgroundColor: on ? FapColors.activeGreen : null,
            disabledBackgroundColor: on ? FapColors.activeGreen : null,
            foregroundColor: FapColors.cyan,
            disabledForegroundColor: Colors.black,
            side: BorderSide(
              color: on ? FapColors.activeGreen : FapColors.cyan,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('TRAINER CONTROLS', style: FapText.label),
          const SizedBox(height: 6),
          Row(
            children: [
              choice('SHOW', true),
              const SizedBox(width: 10),
              choice('HIDE', false),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            show
                ? 'The dashed TRAINER boxes, help notes and FAP CONFIG are '
                      'simulator only, not part of the A320 FAP.'
                : 'Only the real A320 FAP is shown (for an assessment).',
            style: FapText.label,
          ),
        ],
      ),
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');
