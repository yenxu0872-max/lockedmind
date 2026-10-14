# Lockedmind for iPhone

Private AI that runs entirely on the iPhone. Answers come from Apple's on-device model
(the Foundation Models framework, part of Apple Intelligence); the app has no networking
code, no account and no analytics, and works in Airplane Mode.

- **Needs:** iPhone 15 Pro or newer (any iPhone with Apple Intelligence), iOS 26+, Apple Intelligence on.
- **Built with:** SwiftUI, Swift 5 language mode, no third-party code. Xcode 26 or later.

## What's here

| Path | What |
|---|---|
| `Lockedmind.xcodeproj` | The Xcode project (one iPhone app target, files picked up from `Lockedmind/`). |
| `Lockedmind/Brain.swift` | Talks to the model: one session per open chat, rebuilt from saved messages and trimmed to fit the context window; instructions; error wording. |
| `Lockedmind/AppModel.swift` | The open chat, sending, stopping, regenerating, titles. |
| `Lockedmind/Library.swift` | Chats on disk: one JSON file, iOS data protection, left out of backups unless the person opts in. |
| `Lockedmind/*View.swift`, `Markdown.swift`, `Theme.swift` | The screens, the reply renderer, the orb and colours. |
| `Lockedmind/PreviewHarness.swift` | Scripted test runs; only compiled with the `PREVIEW` flag. |
| `AppStore/LISTING.md` | Everything App Store Connect asks for, ready to paste. |
| `AppStore/screenshots/` | 1320 × 2868 screenshots for the 6.9-inch iPhone. |
| `tools/` | `preview.sh` (run the app on the Mac without Xcode), `screenshots.sh` (Simulator → App Store pictures), `frame.py`, `makeicon.swift`. |

The privacy policy and support pages the App Store needs are `web/app/privacy.html` and
`web/app/support.html`; they go live with the website.

## Run it

1. Open `Lockedmind.xcodeproj` in Xcode.
2. **In the Simulator:** pick an iPhone (15 Pro or newer) and press Run. The Simulator uses
   this Mac's Apple Intelligence for the model.
3. **On your own iPhone:** plug it in, choose it as the run destination, then in the target's
   *Signing & Capabilities* tab pick your Apple ID as the Team (Xcode › Settings › Accounts
   to add one). Turn on Developer Mode on the phone when asked. With a free Apple ID the app
   runs for 7 days before it needs re-installing from Xcode.

No Xcode? `tools/preview.sh build` builds the same code as a Mac app with only the Command Line
Tools, and `tools/preview.sh run tools/shots.txt OUTDIR` runs the scripted tour.

## Put it on the App Store

1. Join the **Apple Developer Program** (US $99 a year) at developer.apple.com. Apple requires
   the person who enrols to be an adult (18 or over in most countries); a parent or guardian
   can enrol and add you to their team.
2. In Xcode, set the Team to that account. Keep or change the bundle ID
   (`io.github.yenxu0872-max.lockedmind`).
3. In **App Store Connect** › Apps › **+** › New App: iOS, name *Lockedmind – Private AI*,
   the same bundle ID, SKU `lockedmind-ios`.
4. In Xcode: choose *Any iOS Device*, then **Product › Archive**, then **Distribute App ›
   App Store Connect**. When it finishes processing the build appears in App Store Connect.
5. Fill in the listing from `AppStore/LISTING.md`, upload the screenshots, set App Privacy to
   *Data Not Collected*, pick the build and **Submit for Review**.

Before submitting, the privacy policy and support pages must be live (push the website).

## Make the App Store screenshots

```bash
tools/screenshots.sh
```

Builds the app for a 6.9-inch Simulator, runs `tools/shots.txt` (real questions, real
answers), captures each screen with a clean 9:41 status bar and frames it with a headline.
