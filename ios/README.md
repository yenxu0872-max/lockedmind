# Lockedmind for iPhone

Private AI that runs entirely on the iPhone, designed as a private journal kept by a living
mind: Geist type on warm paper, questions joined to answers by a thread of light, and the logo
(a violet-to-sky orb with a keyhole lit from inside) glowing while it thinks. Answers come from
Apple's on-device model (the Foundation Models framework, part of Apple Intelligence). The app
never connects to the internet (it only watches whether the iPhone is online, to show it), has
no account and no analytics, and works in Airplane Mode.

Features: streaming answers with stop, regenerate, copy, share and read aloud; follow-up
suggestions; edit a question and ask again; photos, document scans and PDF/text files read on
the device (iOS 27 can also look at photos); on-device dictation; chat search, pin, rename,
share, export and delete; answer length, tone and creativity; "about you"; a memory meter and a
marker where older messages fall out of the model's memory; online/offline badge; Face ID lock;
chats kept out of backups unless chosen.

- **Needs:** iPhone 15 Pro or newer (any iPhone with Apple Intelligence), iOS 26+, Apple Intelligence on.
- **Built with:** SwiftUI, Swift 5 language mode, no third-party code. Xcode 26 or later.

## What's here

| Path | What |
|---|---|
| `Lockedmind.xcodeproj` | The Xcode project (one iPhone app target, files picked up from `Lockedmind/`). |
| `Lockedmind/Brain.swift` | Talks to the model: one session per open chat, rebuilt from saved messages and trimmed to fit the context window; instructions; error wording. |
| `Lockedmind/AppModel.swift` | The open chat, sending, stopping, regenerating, titles. |
| `Lockedmind/Library.swift` | Chats on disk: one JSON file, iOS data protection, left out of backups unless the person opts in. |
| `Lockedmind/Lock.swift` | The optional Face ID lock (LocalAuthentication; iOS does the checking). |
| `Lockedmind/Attachments.swift` | Photos, scans and files: read on the device (Vision text recognition, PDFKit), the document camera. |
| `Lockedmind/Speech.swift` | On-device dictation (refuses rather than use server recognition) and read-aloud. |
| `Lockedmind/Connection.swift` | The online/offline badge (Network path monitoring; sends nothing). |
| `Lockedmind/Fonts/` | Geist and Geist Mono (SIL Open Font License), loaded at launch. |
| `Lockedmind/*View.swift`, `Markdown.swift`, `Theme.swift` | The screens; the serif reply renderer; the living orb, the glow, the paper colours. |
| `Lockedmind/PreviewHarness.swift` | Scripted test runs; only compiled with the `PREVIEW` flag. |
| `AppStore/LISTING.md` | Everything App Store Connect asks for, ready to paste. |
| `AppStore/screenshots/` | Six 1320 × 2868 screenshots for the 6.9-inch iPhone, from the Simulator. |
| `AppStore/Logo.png` | The logo on a transparent background, 1024 px. |
| `tools/` | `screenshots.sh` (Simulator → App Store pictures, with `shots.txt`, `samples.py`, `frame.swift`), `makeicon.swift` (the icon and logo). |

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

To test without tapping: build with `SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG PREVIEW'` and launch
with `SIMCTL_CHILD_LM_SCRIPT=<script>`; `PreviewHarness.swift` lists the script commands.

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
