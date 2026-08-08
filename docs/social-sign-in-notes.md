# OurPlaces — Social Sign-In Notes (Google & Apple)

Reference for how "Sign in / Sign up with Google" and "Sign in / Sign up with Apple"
are implemented, what needs to be configured, and how to test.

> **Key concept:** With OAuth/OIDC there is **no separate sign-up vs sign-in**.
> The same flow signs in an existing user *or* creates a new account on first use.
> So the "Sign up with…" and "Sign in with…" buttons do the exact same thing.

Both providers end the same way:
`provider login → ID token → supabase.auth.signInWithIdToken(...) → Supabase session → authState.signIn() → Home`.

---

## Project facts

- **Supabase project ref:** `vkcytomtcibaaruzpdyr`
- **Supabase callback URL:** `https://vkcytomtcibaaruzpdyr.supabase.co/auth/v1/callback`
- **App bundle ID:** `charan.OurPlaces`
- **Google iOS client ID:** `1067972273726-tsfa56p6hr7fu6ohq1l5bf3e78n5r2c4.apps.googleusercontent.com`
- **Google Web client ID:** `1067972273726-k067oktvouohejkdkkvg88jd6am3hb2h.apps.googleusercontent.com`
- **Reversed iOS client ID (URL scheme):** `com.googleusercontent.apps.1067972273726-tsfa56p6hr7fu6ohq1l5bf3e78n5r2c4`

---

## Google Sign-In

### How it works
1. Tap the Google button → native Google account picker (GoogleSignIn-iOS SDK).
2. SDK returns an **ID token** + access token.
3. `supabase.auth.signInWithIdToken(provider: .google, idToken:, accessToken:)` → session.
4. Profile name + avatar backfilled from the Google account (first sign-in only).

### Code
- `OurPlaces/Managers/GoogleAuthManager.swift` — runs the picker + token exchange; handles user-cancel.
- `OurPlaces/OurPlacesApp.swift` — `.onOpenURL { GIDSignIn.sharedInstance.handle($0) }`.
- Buttons wired in `LoginView.swift` & `SignupView.swift` → `handleGoogleSignIn()`.
- SDK: **GoogleSignIn-iOS 9.x** (Swift Package).

### Info.plist keys
- `GIDClientID` = the iOS client ID.
- `CFBundleURLTypes` → URL scheme = the **reversed** iOS client ID.

### Dashboard config (done in the browser, not in code)
- **Google Cloud Console:**
  - OAuth consent screen configured.
  - **Web** OAuth client — authorized redirect URI = the Supabase callback URL.
  - **iOS** OAuth client — Bundle ID `charan.OurPlaces`.
- **Supabase → Auth → Providers → Google:**
  - Enabled.
  - **Client IDs** field (comma-separated) contains **both** the Web client ID **and** the iOS client ID.
  - **Skip nonce checks = ON** (the iOS SDK's token has no nonce we can supply).
  - Client Secret = the Web client's secret.

### Status
Verified in simulator up to Google's real login page ("to continue to OurPlaces").
Finishing a real login requires entering a Google account (do this on your side).

---

## Apple Sign-In

### How it works
1. Tap the Apple button → native Sign in with Apple sheet (Face ID / passkey).
2. We generate a **nonce**; SHA256(nonce) is sent to Apple, raw nonce kept.
3. Apple returns a signed **ID token** (and the user's **name only on the first authorization**).
4. `supabase.auth.signInWithIdToken(provider: .apple, idToken:, nonce: rawNonce)` → session.
5. Name backfilled to the profile if we got it.

### Code
- `OurPlaces/Managers/AppleAuthManager.swift` — `ASAuthorizationController` + CryptoKit nonce; handles cancel.
- Entitlement `com.apple.developer.applesignin` added in `OurPlaces/OurPlaces.entitlements`.
- Buttons wired in `LoginView.swift` & `SignupView.swift` → `handleAppleSignIn()`.
- No third-party SDK (uses Apple's `AuthenticationServices`).

### Dashboard config (to do on your side)
- **Apple Developer portal:** enable the **Sign in with Apple** capability for App ID `charan.OurPlaces`.
- **Supabase → Auth → Providers → Apple:**
  - Enabled.
  - Add `charan.OurPlaces` as an authorized **Client ID**.
  - **Skip nonce checks = OFF** (unlike Google — we supply a real nonce here).

### Status
Wiring verified in simulator (triggers the real Apple system prompt). Completing a login
needs an Apple Account signed into the device (real device or an iCloud-signed-in simulator).

---

## Profile name/avatar backfill

- `SupabaseAuthVM.backfillProfileIfNeeded(fullName:avatarURL:)`.
- After a social login, fills the `users` row's `full_name` / `avatar_url` from the provider —
  **only if empty**, so a name the user later edits is never overwritten.
- `ProfileView` reads `users.full_name` via `fetchUser()`, so the real name shows after login.

---

## Nonce cheat-sheet (why the two providers differ)

| Provider | Nonce supplied by app? | Supabase "Skip nonce checks" |
|----------|------------------------|------------------------------|
| Google   | No (iOS SDK token has none) | **ON** |
| Apple    | Yes (SHA256→Apple, raw→Supabase) | **OFF** |

---

## App Store note

Offering Google (a third-party login) makes **Sign in with Apple mandatory**
(App Review Guideline **4.8**). Both are now implemented.

---

## Testing checklist

- [ ] Google: finish a real login → lands on Home, name shows in Profile.
- [ ] Apple: run on a real device / iCloud-signed-in simulator → lands on Home, name shows.
- [ ] Confirm Supabase "Client IDs" (Google) includes the iOS client ID.
- [ ] Confirm Skip-nonce: Google ON, Apple OFF.
- [ ] Confirm Apple capability enabled in the Developer portal for the App ID.
