import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'providers/fap_provider.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/fap_simulator_screen.dart';
import 'screens/unlock_screen.dart';
import 'screens/update_dialog.dart';
import 'services/access_lock.dart';
import 'services/update_service.dart';
import 'theme/fap_theme.dart';
import 'widgets/blink.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // The FAP is a landscape panel; run full-screen like the real unit.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  final fap = FapProvider();
  await fap.load();
  final unlocked = await AccessLock.isUnlocked();
  final demo = !unlocked && await AccessLock.isDemo();

  runApp(
    AisatFapApp(
      fap: fap,
      unlocked: unlocked,
      demo: demo,
      checkLicenseOnline: unlocked,
      checkUpdates: true,
    ),
  );
}

class AisatFapApp extends StatefulWidget {
  const AisatFapApp({
    super.key,
    required this.fap,
    this.unlocked = true,
    this.demo = false,
    this.showDisclaimer = true,
    this.checkLicenseOnline = false,
    this.checkUpdates = false,
  });

  final FapProvider fap;

  /// False until this device has a license: the start screen is shown.
  final bool unlocked;

  /// Demo version chosen earlier (no license yet).
  final bool demo;

  /// The notice is shown at every start, after the license screen.
  final bool showDisclaimer;

  /// In the background, ask the server whether this device still holds its
  /// license (it may have been transferred). Never blocks start-up.
  final bool checkLicenseOnline;

  /// Ask the website for a newer version; offered once the panel shows.
  final bool checkUpdates;

  @override
  State<AisatFapApp> createState() => _AisatFapAppState();
}

class _AisatFapAppState extends State<AisatFapApp> {
  // Shared by every route, so a new route (e.g. a web URL change) never
  // shows the lock again once the code has been entered.
  late final _unlocked = ValueNotifier<bool>(widget.unlocked);
  late final _demo = ValueNotifier<bool>(widget.demo);
  late final _agreed = ValueNotifier<bool>(!widget.showDisclaimer);
  final _update = ValueNotifier<UpdateInfo?>(null);
  bool _updateOffered = false;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (widget.checkLicenseOnline) _checkLicense();
    if (widget.checkUpdates) {
      UpdateService.check().then((u) {
        if (mounted) _update.value = u;
      });
    }
  }

  /// Offers the update once, when the panel is on screen.
  void _offerUpdate() {
    final info = _update.value;
    if (info == null || _updateOffered) return;
    _updateOffered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) showUpdateDialog(ctx, info);
    });
  }

  Future<void> _checkLicense() async {
    final still = await AccessLock.stillLicensed();
    if (!still && mounted) _deactivated();
  }

  void _deactivated() {
    _unlocked.value = false;
    _demo.value = false;
  }

  @override
  void dispose() {
    _unlocked.dispose();
    _demo.dispose();
    _agreed.dispose();
    _update.dispose();
    super.dispose();
  }

  void _licensed() {
    _unlocked.value = true;
    _demo.value = false;
  }

  @override
  Widget build(BuildContext context) {
    Route<void> home() => MaterialPageRoute<void>(
      builder: (_) => ListenableBuilder(
        listenable: Listenable.merge([_unlocked, _demo, _agreed, _update]),
        builder: (_, _) {
          if (!_unlocked.value && !_demo.value) {
            return UnlockScreen(
              onUnlocked: _licensed,
              onDemo: () => _demo.value = true,
            );
          }
          if (!_agreed.value) {
            return DisclaimerScreen(onAgree: () => _agreed.value = true);
          }
          _offerUpdate();
          return FapSimulatorScreen(
            demo: !_unlocked.value,
            onLicensed: _licensed,
          );
        },
      ),
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.fap),
        ChangeNotifierProvider(create: (_) => Blink()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // Any start URL (e.g. the web simulator's #/fap link) opens the same
        // single screen.
        onGenerateInitialRoutes: (_) => [home()],
        onGenerateRoute: (_) => home(),
      ),
    );
  }
}
