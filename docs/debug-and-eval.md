# Debug tools and eval

Release builds contain none of this: the eval screen, previews, autorun arguments and stats
files are all behind `#if DEBUG`.

1. To see onboarding again: Settings tab › Debug › **Show onboarding again** (the model stays
   downloaded, so it goes straight to Start). For a true fresh-install demo, delete the app.
2. Eval: create an album named exactly **Sloth Test** in Photos with the test screenshots
   (kept on the device, not only in iCloud). Settings › Debug › eval screen, or launch with
   the argument `-evalAutorun` (Xcode: Scheme › Run › Arguments, or
   `xcrun devicectl device process launch --device <UDID> com.martinespericueta.slothroll -- -evalAutorun`).
   Copy the report off the phone with
   `xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer --domain-identifier com.martinespericueta.slothroll --source Documents/eval-report.json --destination eval-report.json`.
3. Scan timing run: launch with `-scanAutorun -scanReset` (clears the cache except cards
   already done, then scans). Autorun arguments skip onboarding. Stats land in
   `Documents/scan-stats.json`; copy them off with the command above and
   `--source Documents/scan-stats.json`. Keep the phone unlocked.
4. Clean up thresholds (`PipelineConfig`): watch the `analyze sharpness=` debug logs in
   Console while scanning.
5. If you deny Calendars, turn it on in Settings › Apps › Sloth Roll › Calendars. With
   limited Photos access only the photos you picked are scanned or deleted.

## Logs

Console.app, filter subsystem `SlothRoll`, category `eval` (per-image timings and the
run summary), `pipeline` (attempts, parse failures, `scan_done` summary, memory warnings,
`analyze sharpness=` per image at debug level, `cleanup_rules`, `cleanup_ask`), `cleanup`
(deletes, counts only), `storage`, `scan`, `onboarding`, `settings`, or `inference`.

## Accuracy and limits

- **Languages:** the prompt and test set are Spanish and English only. Other languages may
  work by luck but weren't tested; weekday names and relative dates ("mañana", "this
  Saturday") are only spelled out in those two.
- **Accuracy (from the eval screen, 19 hand-checked images, iPhone 17 Pro):** the type
  (event / place / receipt / none) was right on 18 of 19 (95%), and all 6 junk images came
  back "none". The miss: a cinema purchase history read as an event instead of a receipt.
  Fields are weaker: date and time both right on 6 of 10 events. Known slips: a chat
  timestamp or the status-bar clock taken as the event time, a past "25 abr" with no year
  dated this year instead of next, the same "sábado" landing on different days between
  runs. Relative dates were right on 4 of 5. The eval set is small; treat these numbers as
  a sanity check, not a benchmark. Cards marked low confidence show "not sure", and every
  card can be edited before you swipe.
- **Speed:** about 4 to 8 seconds per image once the model is loaded (median 7.8 s in the
  eval, 4.3 s per image in a 43-image scan). A 50-image scan takes a few minutes; keep the
  app open (it keeps the screen awake while scanning).
- **Clean up thresholds** (blur, duplicates) are educated guesses, not tuned on many
  phones. Only a clear "no" from the model marks a screenshot not useful, so it errs on
  keeping.
- **Places:** opening a place uses Apple's place search, which needs a connection; offline,
  Maps gets a plain text search. Event times use the phone's current time zone.
- The edit sheet can't change a card's type (a receipt read as an event stays an event).
- Expenses stay in the app; there's no export.
- iPhone only, portrait only. Needs an Apple-silicon iPhone with enough memory for a ~2 GB
  model.
