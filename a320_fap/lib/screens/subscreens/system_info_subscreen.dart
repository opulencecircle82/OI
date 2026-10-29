import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cartridge.dart';
import '../../providers/fap_provider.dart';
import '../../config.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/fap_button.dart';

/// SYSTEM INFO page: CIDS health and messages, plus trainer fault
/// injection. With both CIDS directors failed, PA, interphone and
/// passenger signs are lost (ECAM: CIDS 1+2 FAULT).
class SystemInfoSubscreen extends StatelessWidget {
  const SystemInfoSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();

    String dirStatus(int n, bool fault) {
      if (fault) return 'FAULT';
      return fap.activeDirector == n ? 'ACTIVE' : 'STBY';
    }

    Color dirColor(bool fault) => fault ? FapColors.red : FapColors.okGreen;

    final units = <(String, String, Color)>[
      ('CIDS DIRECTOR 1', dirStatus(1, fap.dir1Fault), dirColor(fap.dir1Fault)),
      ('CIDS DIRECTOR 2', dirStatus(2, fap.dir2Fault), dirColor(fap.dir2Fault)),
      ('FAP 1 (FWD)', 'OK', FapColors.okGreen),
      (
        'DEU TYPE A (PAX CABIN)',
        fap.cidsDown ? 'NO DATA' : 'OK',
        fap.cidsDown ? FapColors.amber : FapColors.okGreen,
      ),
      (
        'DEU TYPE B (CREW STATIONS)',
        fap.cidsDown ? 'NO DATA' : 'OK',
        fap.cidsDown ? FapColors.amber : FapColors.okGreen,
      ),
      (
        'PRAM / AUDIO',
        fap.cidsDown ? 'NOT AVAIL' : (fap.pramAvailable ? 'OK' : 'NO PRAM'),
        fap.cidsDown
            ? FapColors.red
            : (fap.pramAvailable ? FapColors.okGreen : FapColors.amber),
      ),
      (
        'PAX SYSTEMS',
        fap.paxSys ? 'ON' : 'OFF',
        fap.paxSys ? FapColors.okGreen : FapColors.textDim,
      ),
      (
        'PED POWER (IN-SEAT POWER)',
        fap.pedPower ? 'ON' : 'OFF',
        fap.pedPower ? FapColors.okGreen : FapColors.textDim,
      ),
      (
        'EVAC SELECTOR (COCKPIT)',
        fap.evacCaptOnly ? 'CAPT' : 'CAPT & PURS',
        fap.evacCaptOnly ? FapColors.amber : FapColors.white,
      ),
      ('CAM (CABIN ASSIGNMENT MODULE)', fap.activeCam.name, FapColors.white),
    ];

    final messages = <(String, Color)>[
      if (fap.cidsDown)
        ('CIDS 1+2 FAULT - PA, INTERPHONE, PAX SIGNS LOST', FapColors.red)
      else if (fap.dir1Fault)
        ('CIDS DIR 1 FAULT - DIR 2 TAKES OVER', FapColors.amber)
      else if (fap.dir2Fault)
        ('CIDS DIR 2 FAULT - NO STANDBY', FapColors.amber),
      if (fap.cidsLightsFull)
        ('NO CIDS SIGNAL - CABIN LIGHTS FULL BRIGHT', FapColors.amber),
      if (fap.lowPressure)
        ('LOW CABIN PRESSURE - LIGHTS BRT, SIGNS ON, PA LOUDER', FapColors.red),
      if (fap.normalPowerLost && fap.emerLights)
        ('NORMAL POWER LOST - EMERGENCY LIGHTS ON', FapColors.red),
      if (fap.lavsInop) ('WASTE TANK FULL - LAVS INOP', FapColors.amber),
      if (fap.anySlideDeployed) ('SLIDE DEPLOYED', FapColors.red),
      for (final s in CardSlot.values)
        if (fap.cardInSlot(s) == null)
          ('NO ${s.label} IN SLOT', FapColors.amber),
      if (fap.screenLocked) ('FAP SCREEN LOCKED', FapColors.white),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 560,
            child: FapPanel(
              title: 'CIDS SYSTEM STATUS',
              child: Column(
                children: [
                  for (final u in units)
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: FapColors.panelBorder),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(u.$1, style: FapText.body)),
                          StatusTag(u.$2, u.$3),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('SOFTWARE', style: FapText.label),
                      const Spacer(),
                      Text(
                        '${AppConfig.brand.isEmpty ? '' : '${AppConfig.brand} '}FAP SIM v${AppConfig.version}',
                        style: FapText.monoStyle(
                          size: 12,
                          color: FapColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FapPanel(
                  title: 'MESSAGES',
                  child: SizedBox(
                    height: 120,
                    child: messages.isEmpty
                        ? Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              'NO MESSAGES',
                              style: FapText.monoStyle(
                                size: 13,
                                color: FapColors.okGreen,
                              ),
                            ),
                          )
                        : ListView(
                            primary: false,
                            padding: EdgeInsets.zero,
                            children: [
                              for (final m in messages)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    m.$1,
                                    style: FapText.monoStyle(
                                      size: 13,
                                      color: m.$2,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
