# Sign in with ChatGPT: Flutter prototype

Path: `prototypes/siwc_prototype/` · Status: **Draft** · Purpose: prove that the ChatGPT login and a plan-funded request work from a Flutter app on macOS, iPad and iPhone, before building it into LearningCape (`docs/PLAN.md`, F6).

Ported from the working Swift implementation in `SearchingFool/Safari-ai-agent` (`app/browser-host/Sources/ChatGPTSIWC.swift`, `ChatGPTResponses.swift`).

## What is verified and what is not
| Item | State |
|---|---|
| Flow logic (dynamic registration, PKCE, loopback callback, ID-token signature check, renewal, revocation, model list, streamed answer) | Passes 9 automated tests against a mock server (`flutter test`) |
| Builds for macOS and iOS | **Not built.** The cloud session has no Xcode |
| Real sign-in against OpenAI | **Not run.** Needs a person with a ChatGPT account |
| Callback arriving while the app is in the background on iPad and iPhone | **Not run.** This is the main question the prototype answers |

## Run it (on a Mac with Xcode and Flutter)
```bash
cd prototypes/siwc_prototype
flutter pub get
flutter test
flutter run -d macos
```
For iPad or iPhone: open `ios/Runner.xcworkspace` in Xcode once, pick your team under Signing & Capabilities, then:
```bash
flutter devices
flutter run -d <device id>
```
The macOS target also needs your team selected in `macos/Runner.xcworkspace`, because the keychain entitlement requires a signed build.

## Test steps on each device
1. Tap **1. Sign in**. The browser opens; sign in and approve.
2. Return to the app. Expect "Sign in: OK" and your account shown.
3. Tap **2. List models**, pick one, tap **3. Ask**. Expect a streamed answer.
4. Close and reopen the app. Expect to still be signed in.
5. Tap **Sign out**.

Record for each device: whether step 2 succeeded, and the "Callback received after Ns" log line. If sign-in on iPad or iPhone only fails when the login takes longer than about 30 seconds, the background time limit is the cause (see below).

## iOS background handling
While the user is in Safari the app is in the background. `ios/Runner/AppDelegate.swift` asks iOS for background time (about 30 seconds) through the `siwc/background` channel. The Swift reference used Apple's Network framework listener; this prototype uses Dart's socket listener. If Dart's listener proves unreliable on iOS, the fallback is to move only the listener into Swift behind the same channel.

## Files
- `lib/siwc.dart`: the client (no Flutter imports).
- `lib/main.dart`: test screen; keychain storage; opens the system browser.
- `test/siwc_test.dart`: mock OpenAI server and tests.
- `ios/Runner/AppDelegate.swift`, `macos/Runner/*.entitlements`: platform settings.

Tokens are stored in the keychain and never written to the log.
