import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show Directory, File, Platform, Process, ProcessStartMode, exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// A newer release found on the website.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.url,
    required this.fileName,
    this.notes = const [],
  });

  final String version;

  /// Download link of the APK (Android) or the Setup exe (Windows).
  final String url;
  final String fileName;
  final List<String> notes;
}

enum UpdateStatus { available, upToDate, unavailable }

class UpdateCheck {
  const UpdateCheck(this.status, [this.info]);
  final UpdateStatus status;

  /// Set when [status] is [UpdateStatus.available].
  final UpdateInfo? info;
}

/// In-app update (the app is not on Play Store): the website publishes
/// version.json with the latest version and download links. A newer
/// version is downloaded and the system installer is opened. Any error
/// (offline, server down) simply means "no update".
class UpdateService {
  UpdateService._();

  static const manifestUrl =
      'https://opulencecircle82.github.io/OI/fap/version.json';
  static const _timeout = Duration(seconds: 15);

  /// Replaced in tests.
  static http.Client Function() clientFactory = http.Client.new;
  static String Function() platformName = _platformName;

  static String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    return 'other';
  }

  /// Updates are offered on Android and Windows only.
  static bool get supported =>
      platformName() == 'android' || platformName() == 'windows';

  /// True when [remote] (e.g. "4.1") is a higher version than [local].
  static bool isNewer(String remote, String local) {
    List<int> parts(String v) =>
        v.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    final r = parts(remote), l = parts(local);
    for (var i = 0; i < r.length || i < l.length; i++) {
      final a = i < r.length ? r[i] : 0, b = i < l.length ? l[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  /// The newer release for this platform, or null (none / offline / error).
  static Future<UpdateInfo?> check({
    String current = AppConfig.version,
  }) async => (await checkNow(current: current)).info;

  /// Asks the website for the latest version.
  static Future<UpdateCheck> checkNow({
    String current = AppConfig.version,
  }) async {
    const unavailable = UpdateCheck(UpdateStatus.unavailable);
    if (!supported) return unavailable;
    final client = clientFactory();
    try {
      final res = await client
          .get(Uri.parse(manifestUrl), headers: {'Cache-Control': 'no-cache'})
          .timeout(_timeout);
      if (res.statusCode != 200) return unavailable;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final version = '${j['version'] ?? ''}';
      final file = j[platformName()];
      if (version.isEmpty || file is! Map<String, dynamic>) return unavailable;
      if (!isNewer(version, current)) {
        return const UpdateCheck(UpdateStatus.upToDate);
      }
      final url = '${file['url'] ?? ''}';
      final name = '${file['name'] ?? ''}';
      // The file name becomes a local path: no folders, no tricks.
      final safeName = RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name);
      if (!url.startsWith('https://') || !safeName) return unavailable;
      return UpdateCheck(
        UpdateStatus.available,
        UpdateInfo(
          version: version,
          url: url,
          fileName: name,
          notes: [for (final n in (j['notes'] as List? ?? const [])) '$n'],
        ),
      );
    } catch (e) {
      debugPrint('UpdateService: no update check: $e');
      return unavailable;
    } finally {
      client.close();
    }
  }

  static const _channel = MethodChannel('fap/device');

  /// Downloads the update file; [onProgress] gets 0..1 (or -1 when the
  /// size is unknown). Throws on failure.
  static Future<File> download(
    UpdateInfo info,
    void Function(double progress) onProgress,
  ) async {
    final dirPath = platformName() == 'android'
        ? await _channel.invokeMethod<String>('updateDir')
        : Directory.systemTemp.path;
    if (dirPath == null) throw StateError('No download folder');
    final file = File('$dirPath${Platform.pathSeparator}${info.fileName}');
    final client = clientFactory();
    try {
      final res = await client
          .send(http.Request('GET', Uri.parse(info.url)))
          .timeout(_timeout);
      if (res.statusCode != 200) {
        throw StateError('Download failed (HTTP ${res.statusCode})');
      }
      final total = res.contentLength ?? 0;
      var got = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in res.stream.timeout(_timeout)) {
          sink.add(chunk);
          got += chunk.length;
          onProgress(total > 0 ? got / total : -1);
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && got != total) {
        throw StateError('Download incomplete');
      }
      return file;
    } finally {
      client.close();
    }
  }

  /// Opens the system installer. On Windows the app closes so the setup
  /// can replace it.
  static Future<void> install(File file) async {
    if (platformName() == 'android') {
      await _channel.invokeMethod<bool>('installApk', {'path': file.path});
    } else if (platformName() == 'windows') {
      await Process.start(file.path, [], mode: ProcessStartMode.detached);
      exit(0);
    }
  }
}
