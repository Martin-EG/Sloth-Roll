# How it works, in detail

Everything the app does today, step by step. The short version is in the
[README](../README.md#how-it-works).

Today (v1.0) a fresh install walks you through four short screens, downloads the model
once, and then opens on three tabs (four when there is something to clean up). On **Scan** you pick what to read (all recent photos, or
one album such as your Screenshots album) and tap **Scan**; the app works through those
images on its own, saving every answer on the phone. Each screenshot with an
action becomes a card; you swipe right to do it, left to skip. **Expenses** lists the
receipts you kept, with a total per currency. **Clean up** appears only when the scan found
screenshots worth deleting (blurry, duplicate, or not useful) and deletes them in one tap,
through iOS's own confirmation. **Settings** sets how many screenshots a scan
reads, can start over from scratch, and says which model runs on the phone.

0. **First launch.** Three intro screens ("You take screenshots. Sloth Roll does the rest.",
   "Everything runs on your iPhone. Nothing is uploaded.", and "Scan one album, then clean
   it up.", which explains picking an album before a scan and deleting the junk after),
   then the model screen: it shows
   the size (1.8 GB), recommends Wi-Fi, and has a **Download** button. While it downloads
   you see a progress bar with "640 MB of 1.8 GB" and the screen stays awake. If it fails
   (no connection, no space) you get a plain message and **Retry**. When it's done, **Start**
   opens the app, and the app remembers that onboarding is finished. If the model is already
   on the phone (reinstall that kept data), the screen goes straight to **Start**. The model
   files are kept out of iCloud backups.
1. **Pick a source (optional).** Above the Scan button a row says "All recent photos" or
   "Album: <name>". Tapping it opens **Scan from**: All recent photos, Photos' Screenshots
   album, then your own albums with image counts (empty, shared, and synced albums aren't
   listed). The choice is remembered; if the album was deleted in Photos, the next scan goes
   back to all recent photos. With an album picked, the steps below look only at the newest
   500 images in that album.

   **Find new images.** The app asks for Photos access (if you only allow some photos, it
   scans those and says so). If access is off, the Scan tab shows "Photos access is off"
   with **Open Settings** (jumps to the app's page in iOS Settings) and **Check again**. It looks at the newest 500 images and skips anything it has
   already seen. Camera photos (files with camera make/model/lens info) are skipped and
   remembered; screenshots and saved images (flyers from WhatsApp, images from Safari) go on.
2. **Triage first, for up to 50 new images** (25, 50, or 100, picked in Settings). Apple's text recognition reads each one. If it
   finds fewer than 20 characters, the image is marked skipped. No model is loaded yet.
3. **Then the model.** The vision model loads once and reads only the images that passed
   triage, one at a time, newest first. Each answer is saved right away: a real action
   (event, place, receipt), "no action", or "couldn't read this one". Then the model is
   unloaded to free about 2 GB. While the scan runs and no cards exist yet, the card area
   says "Reading your screenshots." If the model can't load, an orange message says why,
   the button turns into **Try again**, and the images that passed triage wait for it.
   When a scan ends, one line says what happened: "Found 3 new cards.", "No events,
   places, or receipts in the new screenshots.", or "No new screenshots since the last
   scan."
4. **Stop, pause, resume.** "Stop after this one" finishes the current image and keeps
   everything so far. If iOS warns that memory is low, the app finishes the current image,
   unloads the model, and pauses with a message. Tapping **Resume scan** picks up the images
   that passed triage but weren't read yet.
5. **Review cards.** Every result with an action shows up as a card, newest screenshot
   first: the screenshot, an Event / Place / Receipt badge, the title, and what will happen
   in plain words ("Add event · Sat 25 Oct, 18:00 · Teatro del Estado"). Cards the model
   marked low confidence carry a small "not sure" tag.
   - **Swipe right** (or tap the green button): the card tilts and turns sloth green, then
     the action runs. The phone gives a light tap on every swipe and a success buzz when
     the action is done. A short message says what happened ("Added to Calendar: Feria del Libro,
     Sat 25 Oct") and the card is marked done.
   - **Swipe left** (or **Skip**): the card turns red and is marked skipped. It never comes
     back.
   - **Tap the card** to fix the title, date, time, place, or amount before swiping.
   - If the action can't run (calendar access denied, no date, no amount), the card springs
     back and a message says why. Nothing is lost.
   - With no cards left: "Nothing to do. Very sloth."
6. **What each swipe does.**
   - **Event:** the first time, iOS asks for calendar access (add-only: the app can never
     read your calendar). The event goes into your default calendar: one hour long if it
     has a time, all-day if not.
   - **Place:** Apple Maps opens on the place. The app looks the text up with Apple's place
     search first; if that finds nothing, Maps opens with a plain search for the text.
   - **Receipt:** an expense is saved inside the app (title, amount, currency, date). If the
     receipt has no date, the day of the screenshot is used. Nothing is exported.

7. **Clean up pile.** While triage has each image open it also measures how blurry it is
   and takes Apple's image "fingerprint" (a Vision feature print), so nothing is loaded
   twice. After the model has read the cards, the app looks at the screenshots that ended
   up skipped: too little text, the model found no action, or you swiped them left (those
   are judged on the next scan). Camera photos are never touched.
   - **Blurry:** few sharp edges (but a plain blank screen doesn't count as blurry).
   - **Duplicate:** screenshots whose fingerprints are very close form a group; the newest
     one is kept and the older ones are offered.
   - **Not useful:** for everything else, the same model (still loaded, so no second model)
     is asked one question: "Is this screenshot still useful to keep? Answer only yes or no."
     Only a clear "no" puts it in the pile; anything unclear keeps it. Each screenshot is
     asked once.
   The **Clean up** tab (with a count badge) shows them in a grid, each with a Blurry /
   Duplicate / Not useful badge, all selected. Tap to unselect; **Select all / Deselect
   all** in the corner. **Delete N screenshots** hands them to Photos, which shows its own
   "Allow Sloth Roll to delete…" prompt; they go to Recently Deleted (30 days), never
   deleted for good. If you say no in that prompt, nothing changes. After a delete, the
   ones you unselected are kept for good and never offered again, and the tab disappears
   once you leave it empty.

**Reading one image** (the extraction step):

1. The app builds a prompt (Spanish + English) that includes the day the screenshot was
   taken (from Photos; today if unknown) and the seven days after it, with weekday names.
   So "hoy", "mañana" or "este sábado" mean those days relative to when you took the
   screenshot, not when you scan it. It asks for one JSON object: type (event / place /
   receipt / none, always required), title, date, time, location, amount, currency,
   confidence. Amounts must be money (a price or total); order, folio and booking numbers
   are called out as not amounts. AM/PM times are converted to 24-hour.
2. The on-device model reads the screenshot and answers.
3. The parser cuts the answer down to the JSON object (it ignores chatter, code fences,
   trailing commas, and junk after the object), decodes it, and checks it: the date must be
   a real day, the time a real 24-hour time, the amount not negative. Unknown words for
   type or confidence become the safe choice ("none", "low") instead of an error.
4. If the answer can't be used, the app asks once more with a stricter reminder. If that
   fails too, the screenshot is marked "Couldn't read this one". It never crashes on bad
   output.

**Settings.** "Screenshots per scan" (25 / 50 / 100, default 50). **Rescan everything**
asks first, then forgets what the app read so the next scan reads your screenshots again;
cards you already did stay done (no duplicate events or expenses) and expenses are kept.
The model section shows the model ID, its size, whether it's on the phone, and "Runs
on-device. Nothing is uploaded." Debug builds add a **Debug** section: the eval screen,
**Show onboarding again** (for rehearsing the demo), and the last scan's stats (counts,
timings, peak memory).

**Eval screen (debug builds).** Tap **Load model**, then **Run eval**. The app reads every
image in the Photos album "Sloth Test" (screenshots, saved images, and camera photos; each
row is labeled with its source), runs Apple's text recognition and then the model on
each, and lists thumbnail, type, title, date, amount, and time taken. The summary shows
counts per type, average times, retries, and accuracy. Use the menu on each row to mark it
correct, or wrong and what it should have been. Marks are saved to
`Documents/eval-report.json` and carried over to the next run.
