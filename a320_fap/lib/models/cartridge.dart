// Memory cartridges of the FAP card slots. On the A320 CIDS the FAP SET-UP
// page is used to remove and insert them:
//  * PRAM - pre-recorded announcements and boarding music (airline option),
//  * CAM  - cabin assignment module: layouts, zones and options,
//  * OBRM - on-board replaceable module: the CIDS software.
// After a CAM or OBRM change the new data is loaded by hand on the LAYOUT
// SELECTION or SOFTWARE LOADING page.

import 'cabin_setup.dart';

enum CardSlot {
  pram('PRAM'),
  cam('CAM'),
  obrm('OBRM');

  const CardSlot(this.label);
  final String label;
}

class Cartridge {
  const Cartridge({
    required this.slot,
    required this.id,
    required this.name,
    required this.shortName,
    required this.partNumber,
    required this.contents,
    this.voiceFolder = '',
  });

  final CardSlot slot;
  final String id;
  final String name;

  /// Two-line label for the trainer card case.
  final String shortName;
  final String partNumber;

  /// What is stored on the card (shown in the trainer card case).
  final String contents;

  /// PRAM only: sub-folder of assets/pram/ with this card's recordings
  /// ('' = the ORIGINAL card in assets/pram/).
  final String voiceFolder;
}

/// Simulated PRAM cards: the same announcements and music, each recorded
/// by a different female voice.
const pramCards = <Cartridge>[
  Cartridge(
    slot: CardSlot.pram,
    id: 'pram_orig',
    name: 'ORIGINAL PRAM',
    shortName: 'ORIGINAL\nJenny',
    partNumber: 'PRM-A320-01',
    contents: 'Voice Jenny (female, US)',
  ),
  Cartridge(
    slot: CardSlot.pram,
    id: 'pram_aria',
    name: 'PRAM CARD 2',
    shortName: 'CARD 2\nAria',
    partNumber: 'PRM-A320-02',
    contents: 'Voice Aria (female, US)',
    voiceFolder: 'aria',
  ),
  Cartridge(
    slot: CardSlot.pram,
    id: 'pram_michelle',
    name: 'PRAM CARD 3',
    shortName: 'CARD 3\nMichelle',
    partNumber: 'PRM-A320-03',
    contents: 'Voice Michelle (female, US)',
    voiceFolder: 'michelle',
  ),
  Cartridge(
    slot: CardSlot.pram,
    id: 'pram_sonia',
    name: 'PRAM CARD 4',
    shortName: 'CARD 4\nSonia',
    partNumber: 'PRM-A320-04',
    contents: 'Voice Sonia (female, UK)',
    voiceFolder: 'sonia',
  ),
  Cartridge(
    slot: CardSlot.pram,
    id: 'pram_natasha',
    name: 'PRAM CARD 5',
    shortName: 'CARD 5\nNatasha',
    partNumber: 'PRM-A320-05',
    contents: 'Voice Natasha (female, AU)',
    voiceFolder: 'natasha',
  ),
];

const camCards = <Cartridge>[
  Cartridge(
    slot: CardSlot.cam,
    id: camOriginalId,
    name: 'ORIGINAL CAM',
    shortName: 'ORIGINAL\nCAM',
    partNumber: 'Z053H0000010',
    contents: 'Layouts: 1 class / 2 classes / 3 classes',
  ),
  Cartridge(
    slot: CardSlot.cam,
    id: camHighDensityId,
    name: 'CAM B',
    shortName: 'CAM B\nHIGH DENS.',
    partNumber: 'Z053H0000020',
    contents: 'Layouts: 1 class 31 rows / 2 classes / 2 classes',
  ),
];

/// CIDS software held by an OBRM, per component part.
class ObrmSoftware {
  const ObrmSoftware({
    required this.mainboard,
    required this.dib,
    required this.sdf,
    required this.fap,
  });

  final String mainboard;
  final String dib;
  final String sdf;
  final String fap;
}

const obrmCards = <Cartridge>[
  Cartridge(
    slot: CardSlot.obrm,
    id: 'obrm_a',
    name: 'OBRM 037A',
    shortName: '037A\nOLDER',
    partNumber: 'Z064H010037A',
    contents: 'CIDS software, older standard',
  ),
  Cartridge(
    slot: CardSlot.obrm,
    id: 'obrm_b',
    name: 'OBRM 037B',
    shortName: '037B\nNEWER',
    partNumber: 'Z064H010037B',
    contents: 'CIDS software, newer standard',
  ),
];

const obrmSoftware = <String, ObrmSoftware>{
  'obrm_a': ObrmSoftware(
    mainboard: 'KID09-DMB1-126',
    dib: 'KID15-DIB3-332',
    sdf: 'KID15-DF2-123',
    fap: 'KID11-FAP3-311',
  ),
  'obrm_b': ObrmSoftware(
    mainboard: 'KID09-DMB1-127',
    dib: 'KID15-DIB3-333',
    sdf: 'KID15-DF2-124',
    fap: 'KID11-FAP3-311',
  ),
};

List<Cartridge> cardsFor(CardSlot slot) => switch (slot) {
  CardSlot.pram => pramCards,
  CardSlot.cam => camCards,
  CardSlot.obrm => obrmCards,
};

Cartridge? cardById(String? id) {
  for (final slot in CardSlot.values) {
    for (final c in cardsFor(slot)) {
      if (c.id == id) return c;
    }
  }
  return null;
}

/// Cards in the slots when the simulator starts (or is reset).
const defaultCards = <CardSlot, String>{
  CardSlot.pram: 'pram_orig',
  CardSlot.cam: camOriginalId,
  CardSlot.obrm: 'obrm_b',
};
