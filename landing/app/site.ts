export const BASE_PATH = "/OI";

export const supabase = {
  url: "https://spaxgxlhfuasehumkglb.supabase.co",
  // Publishable key: the database only exposes RPC functions to it.
  key: "sb_publishable_j1RmQ4wKmspwz0URRLvdTQ_7_iYrvGi",
};

const repoUrl = "https://github.com/opulencecircle82/OI";

/** Download link of a file attached to the GitHub release [tag]. Each app
 * has its own release, so links name the tag (not "latest"). */
const releaseFile = (tag: string, file: string) =>
  `${repoUrl}/releases/download/${tag}/${file}`;

export const site = {
  repoUrl,
  pageUrl: "https://opulencecircle82.github.io/OI/",
};

/** A320 FAP Simulator (cabin crew). */
export const fap = {
  /** Show the license-code text once the activation database is live. */
  licensing: true,
  version: "3.9",
  releaseTag: "v3.9.0",
  apkName: "A320_FAP_v3.9.apk",
  get apkUrl() {
    return releaseFile(this.releaseTag, this.apkName);
  },
  /** Windows installer (Inno Setup), attached to the same release. */
  windowsName: "A320_FAP_Setup_v3.9.exe",
  get windowsUrl() {
    return releaseFile(this.releaseTag, this.windowsName);
  },
  /** User manual PDF (built from /manual, copied to landing/public). */
  manualPath: `${BASE_PATH}/A320_FAP_User_Manual.pdf`,
  /** Feature sources & A320 conformance report (built from /manual/sources.html). */
  reportPath: `${BASE_PATH}/A320_FAP_Sources_and_Conformance.pdf`,
  /** Instructor guide (built from PRIVATE_instructor_guide, copied to landing/public). */
  guidePath: `${BASE_PATH}/A320_FAP_Instructor_Guide.pdf`,
  /** YouTube tutorial (school-free version). */
  tutorialId: "KAeq-nrS088",
  get tutorialUrl() {
    return `https://www.youtube.com/watch?v=${this.tutorialId}`;
  },
};

/** A320 MCDU Trainer (pilots: MCDU, ND and weather radar). */
export const mcdu = {
  version: "2.0",
  releaseTag: "mcdu-v2.0",
  apkName: "A320_MCDU_Trainer_v2.0.apk",
  get apkUrl() {
    return releaseFile(this.releaseTag, this.apkName);
  },
  /** Windows installer (Inno Setup), attached to the same release. */
  windowsName: "A320_MCDU_Trainer_Setup_v2.0.exe",
  get windowsUrl() {
    return releaseFile(this.releaseTag, this.windowsName);
  },
  /** Instructor guide and sources report (built in the MCDU project's
   * guide folder, copied to landing/public). */
  guidePath: `${BASE_PATH}/A320_MCDU_Trainer_Instructor_Guide.pdf`,
  reportPath: `${BASE_PATH}/A320_MCDU_Trainer_Sources_and_Conformance.pdf`,
  /** YouTube tutorial (v2.0: complete flight, cold & dark to shutdown). */
  tutorialId: "L5dC84HcGtA",
  get tutorialUrl() {
    return `https://www.youtube.com/watch?v=${this.tutorialId}`;
  },
};

/** Prefix a public asset with the GitHub Pages base path. */
export const asset = (path: string) => `${BASE_PATH}${path}`;
