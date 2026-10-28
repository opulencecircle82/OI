import 'dart:io' show File;

import 'package:flutter/material.dart';

import '../config.dart';
import '../services/update_service.dart';
import '../theme/fap_theme.dart';

/// "Update available": UPDATE NOW downloads the new version and opens the
/// installer; LATER closes the dialog (the app asks again at next start).
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: SingleChildScrollView(child: _UpdateCard(info: info)),
    ),
  );
}

enum _Step { offer, downloading, installing, failed }

class _UpdateCard extends StatefulWidget {
  const _UpdateCard({required this.info});
  final UpdateInfo info;

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  _Step _step = _Step.offer;
  double _progress = 0;
  File? _file;

  bool get _android => UpdateService.platformName() == 'android';

  Future<void> _update() async {
    setState(() {
      _step = _Step.downloading;
      _progress = 0;
    });
    try {
      final file =
          _file ??
          await UpdateService.download(widget.info, (p) {
            if (mounted) setState(() => _progress = p);
          });
      _file = file;
      if (!mounted) return;
      setState(() => _step = _Step.installing);
      await UpdateService.install(file);
    } catch (e) {
      debugPrint('Update failed: $e');
      if (mounted) setState(() => _step = _Step.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    Widget button(String label, VoidCallback? onTap, {bool primary = true}) =>
        primary
        ? FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: FapColors.activeGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          )
        : TextButton(onPressed: onTap, child: Text(label));

    final List<Widget> body;
    final List<Widget> actions;
    switch (_step) {
      case _Step.offer:
        body = [
          Text(
            'Version ${info.version} is available. You have version '
            '${AppConfig.version}.',
            style: FapText.body,
          ),
          if (info.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text("WHAT'S NEW", style: FapText.label),
            const SizedBox(height: 4),
            for (final n in info.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('•  $n', style: FapText.body),
              ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Your license stays active after the update.',
            style: FapText.label,
          ),
        ];
        actions = [
          button('LATER', () => Navigator.of(context).pop(), primary: false),
          button('UPDATE NOW', _update),
        ];
      case _Step.downloading:
        body = [
          Text('Downloading version ${info.version}...', style: FapText.body),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _progress < 0 ? null : _progress,
            minHeight: 8,
            color: FapColors.activeGreen,
            backgroundColor: FapColors.inactive,
          ),
          const SizedBox(height: 6),
          Text(
            _progress < 0 ? '' : '${(_progress * 100).round()} %',
            style: FapText.label,
          ),
        ];
        actions = const [];
      case _Step.installing:
        body = [
          Text(
            _android
                ? 'Tap INSTALL on the Android screen.\n\n'
                      'If Android asks, allow "Install unknown apps" for '
                      'A320 FAP, then come back and tap INSTALL.'
                : 'The installer is starting. The app closes now.',
            style: FapText.body,
          ),
        ];
        actions = [
          if (_android) ...[
            button('CLOSE', () => Navigator.of(context).pop(), primary: false),
            button('OPEN INSTALLER AGAIN', _update),
          ],
        ];
      case _Step.failed:
        body = const [
          Text(
            'The update could not be downloaded. Check the internet '
            'connection and try again, or download it from the website.',
            style: FapText.body,
          ),
        ];
        actions = [
          button('CLOSE', () => Navigator.of(context).pop(), primary: false),
          button('TRY AGAIN', _update),
        ];
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Container(
        padding: const EdgeInsets.fromLTRB(26, 20, 26, 20),
        decoration: BoxDecoration(
          color: FapColors.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FapColors.cyan),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.system_update, color: FapColors.cyan),
                SizedBox(width: 10),
                Text('UPDATE AVAILABLE', style: FapText.title),
              ],
            ),
            const SizedBox(height: 16),
            ...body,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final (i, a) in actions.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    a,
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
