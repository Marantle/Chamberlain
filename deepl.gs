/**
 * Google Apps Script for translating the Chamberlain locale CSV with DeepL.
 *
 * Reference copy, does not run from disk. To use it: open the Google Sheet that
 * holds the imported chamberlain-<lang>.csv, go to Extensions > Apps Script,
 * paste this whole file in, save, then reload the sheet. A "Chamberlain" menu
 * appears. Set your key once (setDeeplKey below), then run the menu item.
 *
 * Not shipped with the addon: the Makefile only packages files the .toc names.
 *
 * Two ways to translate:
 *   1. Menu > Chamberlain > Translate empty rows.  This is the one to use for
 *      the whole sheet. It walks the rows one at a time with a throttle and
 *      retries on rate limits, so it does not trip DeepL's 429 the way dragging
 *      a formula down 300 rows does (Sheets fires those in parallel and the free
 *      tier rejects the burst). It is resumable: it skips rows already filled and
 *      skips DO NOT TRANSLATE rows, so if it stops you just run it again.
 *   2. =DEEPL(B2, C2) in a cell.  Fine for spot-checking a row or two. Do not
 *      drag it down the whole column, that is what causes the errors.
 *
 * Columns are found by header name on row 1: "english" (source), "context"
 * (hint), and "draft" (where machine output goes, created if missing). Review
 * the draft into the "finnish" column by hand, that stays the shipped answer.
 *
 * The key lives in Script Properties, never in the sheet or a shared copy. A
 * free-tier key ends in ":fx".
 */

var THROTTLE_MS = 120; // pause between calls so the free tier is not flooded
var MAX_TRIES = 5; // retries on 429 / 5xx before giving up on a row

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu("Chamberlain")
    .addItem("Translate empty rows (DeepL)", "translateSheet")
    .addToUi();
}

function setDeeplKey() {
  // Paste your key between the quotes, run this function once (Run button in the
  // editor), then blank it out again so the key lives only in Script Properties.
  PropertiesService.getScriptProperties().setProperty("DEEPL_KEY", "");
}

// ── Batch runner ────────────────────────────────────────────────────────
function translateSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getActiveSheet();
  var ui = SpreadsheetApp.getUi();

  var key = getKey_();
  if (!key) {
    ui.alert("No DeepL key. Run setDeeplKey in the Apps Script editor, or add DEEPL_KEY under Project Settings > Script Properties.");
    return;
  }

  var data = sheet.getDataRange().getValues();
  var header = data[0].map(function (h) { return String(h).trim().toLowerCase(); });
  var iEng = header.indexOf("english");
  var iCtx = header.indexOf("context");
  if (iEng < 0) {
    ui.alert('No "english" column header found on row 1.');
    return;
  }
  var iDraft = header.indexOf("draft");
  if (iDraft < 0) {
    iDraft = header.length; // append a new draft column
    sheet.getRange(1, iDraft + 1).setValue("draft");
  }

  var endpoint = endpointFor_(key);
  var done = 0, skipped = 0, failed = 0;

  for (var r = 1; r < data.length; r++) {
    var english = String(data[r][iEng] || "");
    var context = iCtx >= 0 ? String(data[r][iCtx] || "") : "";
    var cell = sheet.getRange(r + 1, iDraft + 1);

    if (!english) { continue; }
    if (context.indexOf("DO NOT TRANSLATE") === 0) { skipped++; continue; }
    // Resumable: skip rows already filled, but not ones holding an #ERR marker,
    // so a re-run retries whatever failed last time.
    var existing = String(cell.getValue() || "");
    if (existing && existing.charAt(0) !== "#") { skipped++; continue; }

    var out = deeplTranslate_(english, context, key, endpoint);
    if (out.ok) {
      cell.setValue(out.text);
      done++;
    } else {
      cell.setValue("#ERR " + out.code + " " + out.body);
      failed++;
    }
    SpreadsheetApp.flush();
    Utilities.sleep(THROTTLE_MS);
  }

  ui.alert("DeepL: " + done + " translated, " + skipped + " skipped, " + failed + " failed. Re-run to continue any that failed.");
}

// ── Per-cell function (spot use only) ───────────────────────────────────
/**
 * @param {string} text     English source.
 * @param {string} context  Context hint. Optional.
 * @return {string} Finnish translation with protected tokens intact.
 * @customfunction
 */
function DEEPL(text, context) {
  if (!text) return "";
  var key = getKey_();
  if (!key) return "#NO_KEY";
  var out = deeplTranslate_(String(text), context || "", key, endpointFor_(key));
  return out.ok ? out.text : "#ERR " + out.code + " " + out.body;
}

// ── Internals ───────────────────────────────────────────────────────────
function getKey_() {
  return PropertiesService.getScriptProperties().getProperty("DEEPL_KEY");
}

function endpointFor_(key) {
  // Free tier uses api-free; a paid key uses api.deepl.com.
  return key.slice(-3) === ":fx"
    ? "https://api-free.deepl.com/v2/translate"
    : "https://api.deepl.com/v2/translate";
}

// Prepare text for DeepL's XML tag handling. Because tag_handling=xml parses the
// input as XML, any literal <, >, or & in the source (like "<name>" or
// "Trusted & blocked") would break the parser, so escape those first. Then wrap
// tokens that must survive verbatim (color codes, format placeholders, slash
// commands, and <name>-style tokens) in <x>..</x> so ignore_tags leaves them
// alone. unguard_ reverses both steps on the result.
//
// The slash rule also swallows a known subcommand right after the command
// (/chamberlain delete stays literal, so "delete" is not translated), but only
// from SUBCOMMANDS below, so prose like "/chamberlain hud to restore" protects
// "/chamberlain hud" and still translates "to restore". Add any new slash
// subcommand to that list when the addon gains one.
var SUBCOMMANDS = "build|manage|floor|settings|delete|reset|hud|whatsnew|debug|version";

function guard_(text) {
  var wrap = function (m) { return "<x>" + m + "</x>"; };
  var slash = new RegExp("/(?:chamberlain|rooms)(?:\\s+(?:" + SUBCOMMANDS + "))?", "g");
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\|c[0-9a-fA-F]{8}|\|r/g, wrap) // color codes
    .replace(/%%|%[-+ 0-9.]*[sdfxX]/g, wrap) // placeholders
    .replace(slash, wrap) // slash command + optional known subcommand
    .replace(/&lt;[A-Za-z]+&gt;/g, wrap); // <name>-style tokens (now escaped)
}

// Strip the protection tags, then undo the XML escaping (&amp; last so it does
// not re-expand an escaped entity). Also remove spaces DeepL tends to insert
// right after a color-open code or right before |r, since the English never has
// a space there (|cffFFD700Text|r), so trimming it is safe.
function unguard_(text) {
  return String(text)
    .replace(/<\/?x>/g, "")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/(\|c[0-9a-fA-F]{8}) +/g, "$1")
    .replace(/ +(\|r)/g, "$1");
}

// One translation with retry/backoff. Returns {ok, text} or {ok:false, code, body}.
// Retries 429 (rate limit) and 5xx with exponential backoff plus jitter. Does not
// retry 403/456 (auth / quota), those need a human.
function deeplTranslate_(text, context, key, endpoint) {
  var guarded = guard_(text);
  for (var attempt = 0; attempt < MAX_TRIES; attempt++) {
    var res = UrlFetchApp.fetch(endpoint, {
      method: "post",
      headers: { Authorization: "DeepL-Auth-Key " + key },
      payload: {
        text: guarded,
        source_lang: "EN",
        target_lang: "FI",
        context: context || "",
        model_type: "prefer_quality_optimized",
        tag_handling: "xml",
        ignore_tags: "x",
        outline_detection: "0",
      },
      muteHttpExceptions: true,
    });
    var code = res.getResponseCode();
    if (code === 200) {
      var out = JSON.parse(res.getContentText()).translations[0].text;
      return { ok: true, text: unguard_(out) };
    }
    if (code === 429 || code >= 500) {
      Utilities.sleep(Math.pow(2, attempt) * 500 + Math.floor(Math.random() * 400));
      continue;
    }
    return { ok: false, code: code, body: res.getContentText() };
  }
  return { ok: false, code: 429, body: "rate limited after " + MAX_TRIES + " tries" };
}
