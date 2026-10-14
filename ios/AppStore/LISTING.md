# Lockedmind for iPhone: App Store listing

Everything App Store Connect asks for, ready to paste. Character limits in brackets.
Every claim here is true of the app as built: it uses only Apple's on-device model
(`SystemLanguageModel.default`) and never connects to the internet (it only reads the network state, to show it).

## App information

| Field | Value |
|---|---|
| Name [30] | Lockedmind – Private AI |
| Subtitle [30] | AI chat that stays on iPhone |
| Bundle ID | `io.github.yenxu0872-max.lockedmind` (set in Xcode; change it there if you like) |
| SKU | `lockedmind-ios` |
| Primary category | Productivity |
| Secondary category | Utilities |
| Price | Free |
| Privacy Policy URL | https://yenxu0872-max.github.io/lockedmind/app/privacy.html |
| Support URL | https://yenxu0872-max.github.io/lockedmind/app/support.html |
| Marketing URL (optional) | https://yenxu0872-max.github.io/lockedmind/app/ |
| Copyright | 2026 *your name* |

## Promotional text [170]

Ask, write, plan and learn with an AI that runs entirely on your iPhone. Attach photos and PDFs, dictate, lock it with Face ID. Nothing you write ever leaves your phone.

## Description [4000]

Lockedmind is an AI assistant that runs entirely on your iPhone. Ask it anything, have it write, explain, plan and brainstorm, show it a photo or a PDF, and know that every word stays on your phone.

PRIVATE BY DESIGN
• Answers are worked out on your iPhone by Apple's on-device model. What you write is never sent to us, to Apple or to anyone else.
• No account, no sign-up, no ads, no tracking, no analytics.
• Lockedmind never connects to the internet, so it works the same in Airplane Mode. A live badge shows whether your iPhone is online, and reminds you it doesn't matter.
• Your chats are kept only on your iPhone, and left out of iCloud backups unless you choose otherwise.

EVERYTHING A CHAT ASSISTANT SHOULD DO
• Write messages and emails: a kind no, a tricky reply, a thank-you note.
• Explain things simply, plan your week, brainstorm ideas, help with code.
• Attach photos, scan paper documents with the camera, or open PDFs and text files: Lockedmind reads them on your iPhone and answers questions about them. On iOS 27 it can look at your photos too.
• Dictate instead of typing, with speech recognition that runs on the device.
• Have any answer read aloud.
• Tap a suggested follow-up question, edit a question and ask again, or have an answer written again.
• Search, pin, rename, share and delete chats, or export them all.

LOCKED WITH FACE ID
• Turn on the lock and Lockedmind hides your chats the moment you leave, opening again only for your face (or Touch ID, or your passcode).
• iOS does the checking. Lockedmind never sees your face, fingerprint or passcode.

MADE FOR YOU
• Choose short, balanced or detailed answers; a warm, professional, playful or direct tone; and how creative it should be.
• Tell it your name and what you'd like it to know about you.
• A living orb that glows while it thinks, a thread of light from each question to its answer, and every answer marked "On this iPhone".

WHAT YOU NEED
Lockedmind uses the on-device model that comes with Apple Intelligence, so it needs an iPhone that supports Apple Intelligence (iPhone 15 Pro or newer) running iOS 26 or later, with Apple Intelligence turned on.

GOOD TO KNOW
Lockedmind can't browse the web or look up live information, and like any AI it can make mistakes, so check anything important.

## Keywords [100]

private,offline,chatbot,assistant,ai,chat,on-device,writing,secure,lock,pdf,scan,dictation

(No other apps' names: Apple rejects keywords that use someone else's trademark.)

## What's New (version 1.0)

Hello! This is the first version of Lockedmind for iPhone.

## App Privacy ("nutrition label")

Answer **"No, we do not collect data from this app."** The result is **Data Not Collected**.
That's accurate: the app never connects to the internet (it only watches whether the iPhone is
online, to show it), has no analytics and no third-party SDKs, and its `PrivacyInfo.xcprivacy`
declares no collected data and no tracking. Photos, scans, files and dictation are all handled
on the device; the microphone and camera are used only while the person dictates or scans.

## Age rating

Answer the questionnaire honestly. The facts it asks about:
- It is a general AI chat assistant that writes text about whatever the user asks, filtered by
  Apple's own on-device safety guardrails.
- No user-to-user contact, no web browsing, no ads, no purchases, no gambling, no location.

## Export compliance

Already answered in the app (`ITSAppUsesNonExemptEncryption = NO`): it uses no encryption
beyond what iOS itself provides.

## Notes for App Review

> Lockedmind is an AI chat app built on Apple's Foundation Models framework. It uses only the
> on-device model (SystemLanguageModel.default), has no account or login, and makes no network
> requests at all.
>
> Please review on a device with Apple Intelligence turned on (iPhone 15 Pro or later). On
> devices without Apple Intelligence, the app shows a screen explaining what it needs.
>
> To try it: tap "Begin", then tap one of the suggestions or type a question. The + button
> attaches a photo, a scanned document or a file; the microphone button dictates (on-device
> speech recognition only). The optional Face ID lock is off by default (Settings › Lock with
> Face ID).

## Screenshots

`screenshots/` holds seven, 1320 × 2868 (the 6.9-inch iPhone size App Store Connect asks for),
taken from the real app in the iPhone Simulator with real answers from Apple's model, and framed
with a Geist headline. The note and the lease in them were made for the screenshots
(`tools/samples.py`). Upload them in this order:

1. A private mind that lives on your iPhone
2. Clear answers, and what to ask next
3. Reads your photos and documents, right here
4. Online or offline, nothing you write is sent
5. Locked with Face ID. Open only for you.
6. Your chats stay on this iPhone
7. Speak, scan, attach, all on the device

To make them again: `tools/screenshots.sh` (about five minutes).
