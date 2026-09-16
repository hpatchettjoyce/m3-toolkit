/**
 * Tabletop Simulator Match Logger & Cast Recruiter API
 * Apps Script Backend
 * Date: Sunday, 7 June 2026
 */

// Global Sheet configuration names.
// The `IN ` prefix is the project's convention for a tab that feeds INTO the
// system: `IN TTS` is the match data posted in from Tabletop Simulator,
// `IN Cast` is the card data the web app reads out.
var MATCH_SHEET_NAME = "IN TTS";
// The tab holding all 200 cast cards. Change this if the tab is renamed —
// getCardDatabase() lists the available tabs in its error if it can't find it.
// Note this resolves against the spreadsheet the script is BOUND to, which is
// not necessarily the card database itself.
var CAST_SHEET_NAME = "IN Cast";

// Tab icon for the web app. This has to be set here rather than with a
// <link rel="icon"> in CastRecruiter.html: Apps Script serves the page inside an
// iframe on a Google-owned top-level document, so the HTML's own icon never reaches
// the browser tab. setFaviconUrl() is the supported route and it takes a fetchable
// URL — a data: URI will not do, which is why this needs a hosted raster.
//
// A PUBLIC URL to a SQUARE logomark PNG, ideally 256x256. Use the logomark on its own
// (guide PG.02), not the horizontal lockup — Horizontal_Filled_Light.png is 6208x1331,
// so at 16px of tab it would be an unreadable sliver.
//
// 2026-09-16: the Drive `thumbnail?id=...` form below errored "not supported" for
// Harvey. That URL is a redirect with no image extension, which is the likeliest
// reason. A direct URL ending in .png is the thing to try next — this repo is public,
// so once a square logomark is committed to assets/branding/ its raw URL works:
//   https://raw.githubusercontent.com/hpatchettjoyce/m3-toolkit/main/assets/branding/favicon.png
// Leave it empty and the app simply keeps Apps Script's default icon.
var FAVICON_URL = "https://drive.google.com/thumbnail?id=1QIURzyBekASaxbLyL0rh1Dpqy8s0xzvJ&sz=w256";

/**
 * Serves the HTML frontend interface to clients.
 */
function doGet() {
  var page = HtmlService.createHtmlOutputFromFile('CastRecruiter')
      .setTitle('Monumentum Cast Recruiter')
      .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL)
      .addMetaTag('viewport', 'width=device-width, initial-scale=1');
  // Guarded twice over. The empty check stops setFaviconUrl("") asking the browser for
  // an empty URL; the try/catch stops a URL this API won't accept from taking the whole
  // app down with it, because anything thrown here escapes doGet() and the page never
  // renders. A tab icon is not worth a dead web app.
  if (FAVICON_URL) {
    try {
      page.setFaviconUrl(FAVICON_URL);
    } catch (err) {
      console.warn("setFaviconUrl rejected " + FAVICON_URL + ": " + err);
    }
  }
  return page;
}

/**
 * Handles incoming match logs POSTed by the TTS End Game Controller webhook.
 */
function doPost(e) {
  var lock = LockService.getScriptLock();
  var hasLock = false;
  try {
    // Acquire a 30-second lock to prevent concurrent write collisions in Google Sheets!
    // waitLock() throws if the lock can't be obtained in time, so only flag it as held
    // once the call returns — the finally block must not release a lock we never took.
    lock.waitLock(30000);
    hasLock = true;

    var rawContent = e && e.postData ? e.postData.contents : "";
    if (!rawContent) {
      return ContentService.createTextOutput(JSON.stringify({
        status: "error",
        message: "Request payload was empty."
      })).setMimeType(ContentService.MimeType.JSON);
    }

    var payload = null;
    
    // Resilient Parser: Supports standard application/json, form-urlencoded, or raw serialised payloads
    try {
      payload = JSON.parse(rawContent);
    } catch (jsonErr) {
      if (e && e.parameter) {
        payload = e.parameter;
      } else {
        var parsedParams = parseFormUrlEncoded(rawContent);
        if (Object.keys(parsedParams).length > 0) {
          payload = parsedParams;
        }
      }
    }

    if (!payload) {
      return ContentService.createTextOutput(JSON.stringify({
        status: "error",
        message: "Failed to parse parameters from POST body."
      })).setMimeType(ContentService.MimeType.JSON);
    }

    // Decode nested JSON strings if they were double-serialised by Tabletop Simulator's WebRequest Custom client
    if (typeof payload === 'string') {
      try { payload = JSON.parse(payload); } catch (e) {}
    }

    var winner = payload.winner || "";
    var matchDataJson = payload.matchData || "";
    var matchData = {};

    if (matchDataJson) {
      try {
        matchData = JSON.parse(matchDataJson);
      } catch (err) {
        console.warn("Could not parse nested matchData JSON: " + err.message);
      }
    } else {
      // Direct assignment fallback
      matchData = payload;
    }

    var loadedCasts = matchData.loadedCasts || {};
    var specialActionsLog = matchData.specialActionsLog || [];

    // Map Player Red & Blue cast definitions
    var redCast = loadedCasts.Red || {};
    var blueCast = loadedCasts.Blue || {};

    var redChampion = redCast.champion || "";
    var redDominion = redCast.dominion || "";
    var blueChampion = blueCast.champion || "";
    var blueDominion = blueCast.dominion || "";

    // Open active spreadsheet
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = ss.getSheetByName(MATCH_SHEET_NAME);
    
    // Resilient creation of tracking sheet tab if not present
    if (!sheet) {
      sheet = ss.insertSheet(MATCH_SHEET_NAME);
      // Append standard column headers
      sheet.appendRow([
        "Timestamp (UTC)",
        "Winner",
        "Red Champion",
        "Red Dominion",
        "Red Cast JSON",
        "Blue Champion",
        "Blue Dominion",
        "Blue Cast JSON",
        "Special Actions Log JSON"
      ]);
      sheet.getRange(1, 1, 1, 9).setFontWeight("bold").setBackground("#f1c40f");
    }

    // Append standard row record
    sheet.appendRow([
      new Date().toISOString(), // Standardised ISO timestamp
      winner,
      redChampion,
      redDominion,
      JSON.stringify(redCast),
      blueChampion,
      blueDominion,
      JSON.stringify(blueCast),
      JSON.stringify(specialActionsLog)
    ]);

    return ContentService.createTextOutput(JSON.stringify({
      status: "success",
      message: "Match results logged successfully!"
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (globalErr) {
    console.error("Critical Post Error: " + globalErr.toString());
    return ContentService.createTextOutput(JSON.stringify({
      status: "error",
      message: globalErr.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  } finally {
    if (hasLock) {
      lock.releaseLock();
    }
  }
}

/**
 * Manual URL Parameter Decoder
 */
function parseFormUrlEncoded(rawString) {
  var obj = {};
  if (!rawString) return obj;
  var pairs = rawString.split('&');
  for (var i = 0; i < pairs.length; i++) {
    var parts = pairs[i].split('=');
    if (parts.length === 2) {
      var key = decodeURIComponent(parts[0].replace(/\+/g, ' '));
      var value = decodeURIComponent(parts[1].replace(/\+/g, ' '));
      obj[key] = value;
    }
  }
  return obj;
}

/**
/**
 * Fold a champion name to its comparison form.
 *
 * This is the JavaScript twin of `normalise_name()` in `dextrous/validate_cast.py`
 * — the two MUST stay in step. `Role Details` carries a Dextrous-safe spelling of
 * the champion's name (no commas, no `ae` ligature), so both sides need folding
 * before they can match. A plain string compare resolves 19 of the 24 links and
 * silently drops the other 5. See UPGRADE_PLAN.md §3.1.
 *
 *   1. NFKD-decompose and drop combining marks, then map the ligatures NFKD
 *      leaves alone.
 *   2. Strip commas, apostrophes and periods.
 *   3. Collapse runs of whitespace, trim, lower-case.
 */
var NAME_LIGATURES = {
  "æ": "ae", "Æ": "ae",
  "œ": "oe", "Œ": "oe",
  "ß": "ss",
  "ø": "o", "Ø": "o",
  "đ": "d", "Đ": "d",
  "ł": "l", "Ł": "l"
};

var NAME_STRIPPED_PUNCTUATION = ",'’‘`.´";

function normaliseName(value) {
  var text = String(value === null || value === undefined ? "" : value).normalize("NFKD");
  text = text.replace(/\p{M}/gu, "");

  var folded = "";
  for (var i = 0; i < text.length; i++) {
    var ch = text.charAt(i);
    if (NAME_STRIPPED_PUNCTUATION.indexOf(ch) !== -1) continue;
    folded += NAME_LIGATURES.hasOwnProperty(ch) ? NAME_LIGATURES[ch] : ch;
  }

  return folded.split(/\s+/).filter(function (part) { return part.length > 0; }).join(" ").toLowerCase();
}

/**
 * `CHAMPION` -> `Champion`, `SPECIAL ACTION` -> `Special Action`.
 *
 * The Cast sheet holds classes in all caps; the frontend and the TTS-facing
 * contract both compare against Title Case. Normalising once here is far lower
 * risk than changing every comparison in CastRecruiter.html (UPGRADE_PLAN.md,
 * Chunk 2).
 */
function toTitleCaseClass(value) {
  return String(value || "").toLowerCase().replace(/\S+/g, function (word) {
    return word.charAt(0).toUpperCase() + word.slice(1);
  });
}

/**
 * Build the legacy single `effect` string from the split effect columns.
 *
 * This string is the contract now, not a bridge (D11): the print card renders
 * `formatRulesText(card.effect)` and nothing else, so anything that must reach
 * paper has to be in here. Name and type join with " | "; details go on the next
 * line; a second effect follows on the next line again. Where a card has details
 * but no name/type (113 of 200) the header line is omitted rather than emitting
 * a stray " | ". See UPGRADE_PLAN.md §3.4.
 */
function composeEffectText(effects) {
  var lines = [];
  effects.forEach(function (effect) {
    var header = [effect.name, effect.type].filter(function (part) { return part; }).join(" | ");
    if (header) lines.push(header);
    if (effect.details) lines.push(effect.details);
  });
  return lines.join("\n");
}

// Columns the app actually reads. A missing one is a hard error rather than a
// silent blank: reading a column that isn't there is exactly the bug that made
// the pre-D7 "Name (str)" / "ID (str)" lookups fail without a word.
var CAST_REQUIRED_COLUMNS = [
  "Name", "Dominion", "Class", "Role", "Role Details", "ID",
  "Effect Name 1", "Effect Type 1", "Effect Details 1",
  "Effect Name 2", "Effect Type 2", "Effect Details 2",
  "Ether", "Prowess", "Fortitude"
];

// Passed through for whoever wants them later; nothing consumes these today, so
// a missing one degrades to "" with a warning instead of taking the app down.
var CAST_OPTIONAL_COLUMNS = ["Keywords", "Artwork", "Flavour"];

var CAST_UNIT_CLASSES = { "Familiar": true, "Minion": true, "Talisman": true };

/**
 * Compiles and returns the champion / unit / special database from the single
 * `IN Cast` tab, merged with card art looked up by card ID.
 */
function getCardDatabase() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var castSheet = ss.getSheetByName(CAST_SHEET_NAME);

  if (!castSheet) {
    // Name the tabs that *do* exist. The cast tab has been renamed more than
    // once ("IN CAST" -> "Cast" -> "IN Cast"), and without this the error is a
    // dead end: the fix is always a one-line change to CAST_SHEET_NAME above.
    var available = ss.getSheets().map(function (sheet) { return sheet.getName(); });
    var near = available.filter(function (sheetName) {
      return sheetName.trim().toLowerCase() === CAST_SHEET_NAME.trim().toLowerCase();
    });
    throw new Error('Missing required source spreadsheet tab "' + CAST_SHEET_NAME + '". ' +
        'Tabs in this spreadsheet: ' +
        available.map(function (sheetName) { return '"' + sheetName + '"'; }).join(", ") + '. ' +
        (near.length ? 'Did you mean "' + near[0] + '" (same name, different case or spacing)? ' : '') +
        'Set CAST_SHEET_NAME in main.gs to the tab holding the cast data.');
  }

  var imageMappings = null;
  try {
    imageMappings = getCardImageMappings();
  } catch (err) {
    console.warn("getCardImageMappings is unavailable. Falling back to default styling: " + err.message);
  }
  var artByCardId = (imageMappings && imageMappings.cards) ? imageMappings.cards : {};

  var data = castSheet.getDataRange().getValues();
  if (data.length < 2) {
    throw new Error('The "' + CAST_SHEET_NAME + '" tab has a header but no card rows.');
  }

  var headerMap = {};
  data[0].forEach(function (header, idx) {
    var key = String(header).trim();
    if (key && !headerMap.hasOwnProperty(key)) headerMap[key] = idx;
  });

  var missing = CAST_REQUIRED_COLUMNS.filter(function (column) {
    return !headerMap.hasOwnProperty(column);
  });
  if (missing.length) {
    throw new Error('The "' + CAST_SHEET_NAME + '" tab is missing required column(s): ' +
        missing.join(", ") + ". Re-export the sheet rather than serving blank values.");
  }
  CAST_OPTIONAL_COLUMNS.forEach(function (column) {
    if (!headerMap.hasOwnProperty(column)) {
      console.warn('Optional column "' + column + '" is absent; it will be served as "".');
    }
  });

  var cell = function (row, column) {
    var idx = headerMap.hasOwnProperty(column) ? headerMap[column] : -1;
    return idx === -1 ? "" : String(row[idx]).trim();
  };

  // --- Pass 0: read and validate every row once -----------------------------
  var records = [];
  var seenIds = {};

  for (var r = 1; r < data.length; r++) {
    var row = data[r];
    var sheetRow = r + 1; // 1-based, matching what the user sees in the sheet
    var name = cell(row, "Name");
    var dominion = cell(row, "Dominion");
    var rawClass = cell(row, "Class");
    var cardId = cell(row, "ID");

    // A wholly empty row is trailing slack in the sheet, not a broken card.
    if (!name && !dominion && !rawClass && !cardId) continue;

    if (!name || !dominion || !rawClass || !cardId) {
      throw new Error('Cast row ' + sheetRow + ': every card needs Name, Dominion, Class and ID ' +
          '(got name="' + name + '", dominion="' + dominion + '", class="' + rawClass +
          '", id="' + cardId + '").');
    }
    if (seenIds.hasOwnProperty(cardId)) {
      throw new Error('Cast row ' + sheetRow + ': duplicate ID "' + cardId +
          '", already used on row ' + seenIds[cardId] + '.');
    }
    seenIds[cardId] = sheetRow;

    var unitClass = toTitleCaseClass(rawClass);
    if (unitClass !== "Champion" && unitClass !== "Special Action" &&
        !CAST_UNIT_CLASSES.hasOwnProperty(unitClass)) {
      throw new Error('Cast row ' + sheetRow + ' ("' + name + '"): unrecognised Class "' +
          rawClass + '".');
    }

    records.push({
      sheetRow: sheetRow,
      id: cardId,
      name: name,
      dominion: dominion,
      unitClass: unitClass,
      role: cell(row, "Role").toUpperCase(),
      roleDetails: cell(row, "Role Details"),
      // parseInt("") is NaN, so blank Ether stays 0 and keeps Driplet and
      // Huskling out of the recruitable basics list (frontend `cost > 0`).
      cost: parseInt(cell(row, "Ether"), 10) || 0,
      prowess: cell(row, "Prowess"),
      fortitude: cell(row, "Fortitude"),
      effect1Name: cell(row, "Effect Name 1"),
      effect1Type: cell(row, "Effect Type 1"),
      effect1Details: cell(row, "Effect Details 1"),
      effect2Name: cell(row, "Effect Name 2"),
      effect2Type: cell(row, "Effect Type 2"),
      effect2Details: cell(row, "Effect Details 2"),
      keywords: cell(row, "Keywords"),
      flavourText: cell(row, "Flavour"),
      artwork: cell(row, "Artwork")
    });
  }

  var db = {
    dominions: [],
    champions: [],
    units: [],
    specials: []
  };

  var seenDominions = {};
  records.forEach(function (record) {
    if (!seenDominions.hasOwnProperty(record.dominion)) {
      seenDominions[record.dominion] = true;
      db.dominions.push(record.dominion);
    }
  });

  // Champion links are scoped within the dominion — every dominion has exactly
  // two champions, so a normalised collision is very unlikely, but scoping it
  // costs nothing (UPGRADE_PLAN.md §3.1).
  var championKey = function (dominion, name) {
    return normaliseName(dominion) + "|" + normaliseName(name);
  };

  var championIdByKey = {};

  // Every card carries the same core shape; `id` is the card ID now, not
  // `champ_<index>`, so `tiedChampionId` and `state.champion` share one key
  // space. `uniqueId` stays populated so the roster import/export paths keep
  // working unchanged.
  var baseCard = function (record) {
    return {
      id: record.id,
      uniqueId: record.id,
      name: record.name,
      dominion: record.dominion,
      class: record.unitClass,
      role: record.role,
      roleDetails: record.roleDetails,
      cost: record.cost,
      effect: composeEffectText([
        { name: record.effect1Name, type: record.effect1Type, details: record.effect1Details },
        { name: record.effect2Name, type: record.effect2Type, details: record.effect2Details }
      ]),
      effect1Name: record.effect1Name,
      effect1Type: record.effect1Type,
      effect1Details: record.effect1Details,
      effect2Name: record.effect2Name,
      effect2Type: record.effect2Type,
      effect2Details: record.effect2Details,
      keywords: record.keywords,
      flavourText: record.flavourText,
      artwork: record.artwork,
      image: artByCardId.hasOwnProperty(record.id) ? artByCardId[record.id] : null
    };
  };

  // --- Pass 1: champions, so the links below have something to resolve against
  records.forEach(function (record) {
    if (record.unitClass !== "Champion") return;

    var champion = baseCard(record);
    champion.prowess = record.prowess;
    champion.fortitude = record.fortitude;
    db.champions.push(champion);

    var key = championKey(record.dominion, record.name);
    if (championIdByKey.hasOwnProperty(key)) {
      console.warn('Cast row ' + record.sheetRow + ': two champions in ' + record.dominion +
          ' normalise to the same name ("' + record.name + '"); the later one wins for links.');
    }
    championIdByKey[key] = record.id;
  });

  // --- Pass 2: everything else ----------------------------------------------
  var resolveChampion = function (record, expectedRole) {
    if (!record.roleDetails) {
      console.warn('Cast row ' + record.sheetRow + ' ("' + record.name + '") is marked ' +
          expectedRole + ' but has no Role Details, so it links to no champion.');
      return null;
    }
    var key = championKey(record.dominion, record.roleDetails);
    if (!championIdByKey.hasOwnProperty(key)) {
      console.warn('Cast row ' + record.sheetRow + ' ("' + record.name + '"): Role Details "' +
          record.roleDetails + '" matches no champion in ' + record.dominion + '.');
      return null;
    }
    return championIdByKey[key];
  };

  records.forEach(function (record) {
    if (record.unitClass === "Champion") return;

    if (CAST_UNIT_CLASSES.hasOwnProperty(record.unitClass)) {
      // MINION-class companions belong here too: they are companions that happen
      // to be minions, and the frontend already handles class === 'Minion' in
      // its basics filter (UPGRADE_PLAN.md §3.2).
      var unit = baseCard(record);
      unit.isLoyal = record.role === "COMPANION";
      unit.tiedChampionId = unit.isLoyal ? resolveChampion(record, "COMPANION") : null;
      unit.prowess = record.prowess;
      unit.fortitude = record.fortitude;
      db.units.push(unit);
      return;
    }

    var special = baseCard(record);
    special.isSignature = record.role === "SIGNATURE";
    special.tiedChampionId = special.isSignature ? resolveChampion(record, "SIGNATURE") : null;
    db.specials.push(special);
  });

  // This stringify and parse trick strips out any hidden Google Sheet objects
  // and guarantees the data is perfectly clean for the web browser.
  return JSON.parse(JSON.stringify(db));
}
