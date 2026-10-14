# Lockedmind for iPhone: App Store listing

Everything App Store Connect asks for, ready to paste. Character limits in brackets.
Every claim here is true of the app as built: it uses only Apple's on-device model
(`SystemLanguageModel.default`) and contains no networking code.

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

Ask, write, plan and learn with an AI that runs entirely on your iPhone. No account, no tracking, no internet needed. Your chats never leave your phone.

## Description [4000]

Lockedmind is an AI assistant that runs entirely on your iPhone. Ask it anything, have it write, explain, plan and brainstorm, and know that every word stays on your phone.

PRIVATE BY DESIGN
• Answers are worked out on your iPhone by Apple's on-device model. What you write is never sent to us, to Apple or to anyone else.
• No account, no sign-up, no ads, no tracking, no analytics.
• Lockedmind has no internet code at all, so it works in Airplane Mode.
• Your chats are kept only on your iPhone, and left out of iCloud backups unless you choose otherwise.

GOOD AT EVERYDAY THINGS
• Write messages and emails: a kind no, a tricky reply, a thank-you note.
• Explain things simply: money, science, a confusing term.
• Plan your week, a trip or a party.
• Brainstorm gift ideas, names, recipes and more.
• Help with code, in blocks you can copy.

CALM AND CLEAR
• Answers that get to the point, written as you watch.
• Choose short, balanced or detailed answers.
• Tell it your name and what you'd like it to know about you.
• Search, rename and delete your chats. Copy or share any answer.

WHAT YOU NEED
Lockedmind uses the on-device model that comes with Apple Intelligence, so it needs an iPhone that supports Apple Intelligence (iPhone 15 Pro or newer) running iOS 26 or later, with Apple Intelligence turned on.

GOOD TO KNOW
Lockedmind can't browse the web or look up live information, and like any AI it can make mistakes, so check anything important.

## Keywords [100]

private,offline,chatbot,assistant,ai,chat,on-device,writing,secure,no account,airplane mode,notes

(No other apps' names: Apple rejects keywords that use someone else's trademark.)

## What's New (version 1.0)

Hello! This is the first version of Lockedmind for iPhone.

## App Privacy ("nutrition label")

Answer **"No, we do not collect data from this app."** The result is **Data Not Collected**.
That's accurate: the app has no network code, no analytics and no third-party SDKs, and its
`PrivacyInfo.xcprivacy` declares no collected data and no tracking.

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
> To try it: tap "Start chatting", then tap one of the four suggestions or type a question.

## Screenshots

App Store Connect needs at least one set for the **6.9-inch iPhone** (1320 × 2868 portrait).
`screenshots/` holds five, framed with a headline. The current ones are drafts captured from
the app's own code running on the Mac (`tools/preview.sh`): no status bar, and the Mac greys
out the welcome button. Re-make them from the real app in the iPhone Simulator with
`tools/screenshots.sh` (needs Xcode with the iOS platform). Headlines:

1. Private AI that lives on your iPhone
2. Plans, explains and brainstorms
3. Writes messages for you
4. Nothing you write leaves your phone
5. Your chats, only on this iPhone
