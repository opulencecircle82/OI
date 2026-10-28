// Cabin configuration data held by the CAM (Cabin Assignment Module):
// seat layouts with their passenger classes, boarding music channels and
// the areas whose loudspeaker levels can be adjusted.

enum CabinClass {
  first('FIRST CLASS', 'F/C'),
  business('BUSINESS CLASS', 'B/C'),
  tourist('TOURIST CLASS', 'T/C');

  const CabinClass(this.label, this.short);
  final String label;
  final String short;
}

/// One CAM layout: seat rows and the first row of each class.
class CabinLayout {
  const CabinLayout({
    required this.id,
    required this.cam,
    required this.number,
    required this.rows,
    required this.classes,
    required this.defaultStarts,
  });

  /// Unique over every CAM (keys the saved class borders and counters).
  final int id;

  /// Card id of the CAM that holds this layout.
  final String cam;

  /// Layout number shown on the FAP (1-3 on each CAM).
  final int number;
  final int rows;
  final List<CabinClass> classes;

  /// First seat row of each class, same order as [classes]; starts at 1.
  final List<int> defaultStarts;

  String get description =>
      '${classes.length} ${classes.length == 1 ? 'CLASS' : 'CLASSES'}, '
      '$rows SEATROWS';
}

const camOriginalId = 'cam_orig';
const camHighDensityId = 'cam_b';

const cabinLayouts = <CabinLayout>[
  CabinLayout(
    id: 1,
    cam: camOriginalId,
    number: 1,
    rows: 30,
    classes: [CabinClass.tourist],
    defaultStarts: [1],
  ),
  CabinLayout(
    id: 2,
    cam: camOriginalId,
    number: 2,
    rows: 30,
    classes: [CabinClass.business, CabinClass.tourist],
    defaultStarts: [1, 5],
  ),
  CabinLayout(
    id: 3,
    cam: camOriginalId,
    number: 3,
    rows: 36,
    classes: [CabinClass.first, CabinClass.business, CabinClass.tourist],
    defaultStarts: [1, 4, 11],
  ),
  // CAM B: a second, high-density cabin configuration.
  CabinLayout(
    id: 11,
    cam: camHighDensityId,
    number: 1,
    rows: 31,
    classes: [CabinClass.tourist],
    defaultStarts: [1],
  ),
  CabinLayout(
    id: 12,
    cam: camHighDensityId,
    number: 2,
    rows: 29,
    classes: [CabinClass.business, CabinClass.tourist],
    defaultStarts: [1, 4],
  ),
  CabinLayout(
    id: 13,
    cam: camHighDensityId,
    number: 3,
    rows: 28,
    classes: [CabinClass.business, CabinClass.tourist],
    defaultStarts: [1, 6],
  ),
];

CabinLayout layoutById(int id) =>
    cabinLayouts.firstWhere((l) => l.id == id, orElse: () => cabinLayouts[2]);

/// The layouts stored on CAM [camId].
List<CabinLayout> layoutsOfCam(String camId) =>
    cabinLayouts.where((l) => l.cam == camId).toList();

/// Seat letters of an A320 single-aisle row (3 + 3).
const seatLetters = ['A', 'B', 'C', 'D', 'E', 'F'];

enum BgmChannel {
  blues('Blues'),
  classic('Classic'),
  country('Country'),
  jazz('Jazz');

  const BgmChannel(this.label);
  final String label;
}

/// Areas whose announcement / chime loudspeaker level can be adjusted.
enum LevelGroup {
  cabinZones('CABIN ZONES'),
  attendantAreas('ATTENDANT AREAS'),
  lavatories('LAVATORIES');

  const LevelGroup(this.label);
  final String label;
}

class LevelSetting {
  const LevelSetting({this.announce = 0, this.chime = 0});
  final int announce; // dB
  final int chime; // dB

  LevelSetting copyWith({int? announce, int? chime}) => LevelSetting(
    announce: announce ?? this.announce,
    chime: chime ?? this.chime,
  );
}

class SetupLimits {
  SetupLimits._();
  static const minDb = -6;
  static const maxDb = 6;

  /// Access codes of the protected pages (CIDS defaults).
  static const programmingCode = '318';
  static const softwareCode = '813';
}
