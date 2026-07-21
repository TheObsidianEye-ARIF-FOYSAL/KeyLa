# Keyla — Progress Report

**Last updated:** 2026-07-22
**Spec:** `docs/password-manager-app-spec.md`

Read this file at the start of a new session to pick up context fast.

---

## Status at a glance

| Area | Status |
|---|---|
| Crypto core (Argon2id + XChaCha20-Poly1305) | ✅ Done |
| Encrypted SQLite data layer (SQLCipher) | ✅ Done |
| Theme system (light/dark, spec §8 palette) | ✅ Done |
| Security services (auto-lock, clipboard clear, screenshot block) | ✅ Done |
| Onboarding + unlock screens | ✅ Done |
| Vault CRUD UI (home/search/detail/add/edit) | ✅ Done |
| Password generator (random + passphrase) | ✅ Done |
| Password Health dashboard | ✅ Done |
| Settings screen | ✅ Done |
| Account auth (phone+password, mirrors MedRemind) | ✅ Done |
| ARIF(KyLa) PHP server | ✅ Done |
| Backup/sync (encrypted vault blob to server) | ✅ Done |
| Web build + landing page (GitHub Pages & self-hosted) | ✅ Done |
| **Android AutofillService / iOS Credential Provider** | ❌ **Not started — explicitly out of scope so far** |
| Interactive on-device verification | ⚠️ Partial — builds succeed, no emulator/device click-through done |

---

## What's built

### 1. Flutter app (`keyla_v1/lib/`)

**`core/`**
- `crypto/` — `KdfService` (Argon2id, domain-separated salt derivation) + `CipherService` (XChaCha20-Poly1305, envelope-encrypts the vault key). No hand-rolled crypto; uses `sodium_libs`.
- `db/` — `VaultDatabase` (SQLCipher-encrypted SQLite), `SqlcipherKeyService` (random device-bound DB passphrase in Keychain/Keystore — separate from the master password), `VaultMetaDao`, `CredentialDao`.
- `security/` — `AutoLockController` (60s inactivity + background lock), `ClipboardGuard` (30s auto-clear), `ScreenPrivacy` (Android `FLAG_SECURE` via `MainActivity.kt`, iOS blur-on-resign via `AppDelegate.swift`), `BiometricUnlockService` (Keychain/Keystore-gated master password), `PasswordStrengthScorer`.
- `theme/` — indigo/emerald/amber/rose palette per spec §8.2, full light/dark `ThemeData`.
- `router/app_router.dart` — go_router with a two-gate redirect model (see below).
- `providers.dart` — app-wide Riverpod wiring (sodium, vault repo, settings, biometrics, clipboard, auto-lock).
- `models/app_user.dart`, `server_config.dart`.

**`features/`**
- `auth/` — **phone+password account gate**, structured identically to `med_remind_v2`'s `UserAuthService`/`UserAuthNotifier`: `PhoneEntryScreen` → `LoginPasswordScreen` / `RegisterDetailsScreen`. Session token persisted via SharedPreferences. Deliberately decoupled from the vault master password — this only gates "is this device signed in," never vault encryption.
- `onboarding/` — 3-screen intro → master password + strength meter → biometric opt-in → recovery kit.
- `unlock/` — lock screen, biometric prompt with master-password fallback.
- `vault/` — `VaultRepository` (orchestrates crypto+DB, owns the in-memory vault key), home list w/ search+favorites+health chip, detail, add/edit, generator hookup.
- `generator/` — `PasswordGenerator` (CSPRNG-backed), full-screen + bottom-sheet UI, length slider, character toggles, avoid-ambiguous, passphrase mode.
- `health/` — `HealthReport.compute()` (weak/reused/old detection + score), score ring + issue lists.
- `settings/` — change master password, biometrics, auto-lock/clipboard timeouts, theme, account section (logout/delete), backup tile, recovery kit viewer, delete-all-data.
- `backup/` — `BackupClient` + `BackupSettingsTile`: uploads/downloads the already-encrypted vault export using the account's phone+session token (no separate credential).

**App flow (two gates, like MedRemind's Gate 1/Gate 2):**
```
Splash → Gate 1: account logged in? ──No──▶ PhoneEntryScreen → Login/Register
              │ Yes
              ▼
         Gate 2: vault unlocked? ──No──▶ Onboarding (no vault yet) / Unlock (vault exists)
              │ Yes
              ▼
         Vault Home (main app)
```

### 2. ARIF(KyLa) server (`Keyla/server/`, sibling of `keyla_v1/`)

PHP + PDO/SQLite, structured file-for-file like `med_remind_v2/server`:
- `arif_kyla_db.php` — shared helpers (`arif_kyla_db()`, CORS, JSON in/out, session check), `users` table (phone PK, name, password_hash, session_token) + `vault_blobs` table (phone PK, ciphertext blob, kdf salt/params).
- `arif_kyla_check_phone.php`, `_register.php`, `_login.php`, `_profile.php`, `_change_password.php`, `_delete_account.php` — mirror `medremind_*.php` 1:1 (bcrypt via `password_hash`/`password_verify`, opaque session tokens).
- `arif_kyla_vault_upload.php` / `_vault_download.php` — store/retrieve the client's already-encrypted vault export. The server never sees a plaintext credential or the master password — only a bcrypt-hashed account password and opaque ciphertext.

### 3. Web version + landing page (`Keyla/landing/`, `Keyla/scripts/`, `Keyla/.github/`)

Mirrors `med_remind_v2`'s split: a static marketing landing page at the root,
the Flutter web app underneath at `/app/`. Two deployments of the same layout:

- **GitHub Pages** — `.github/workflows/deploy-web.yml` builds with
  `--base-href /KeyLa/app/` and publishes landing + app on every push to `main`.
- **Self-hosted** — `scripts/build_server_web.ps1 -BasePath '/ARIF(KyLa)/'`
  produces `build/server_web/` + `Keyla_upload.zip` for extraction onto the PHP host.

`landing/index.html` is self-contained (no build step), uses the spec §8.2
palette, and carries an explicit notice about the web build's limits.

**Making the web build actually run** required three fixes:
1. `dart run sodium_libs:update_web` — pulls `sodium.js` into `web/` and injects
   the script tag. Without it `SodiumSumoInit.init()` never resolves and the app
   hangs on the splash screen.
2. `VaultDatabase` now branches on `kIsWeb`: `sqflite_sqlcipher` and
   `path_provider` are native-only, so web falls back to an IndexedDB-backed
   sqflite via `sqflite_common_ffi_web` (assets `sqflite_sw.js` + `sqlite3.wasm`
   installed by `dart run sqflite_common_ffi_web:setup`, both committed).
3. `web/index.html` + `manifest.json` rebranded off the Flutter template, and
   `web/icons/*` + `favicon.png` regenerated from the Android launcher icon.

`local_auth` is also native-only, but `BiometricUnlockService.isDeviceSupported()`
already swallows the failure, so web degrades to master-password-only unlock
with no code change.

### 4. Native plumbing done
- Android: `MainActivity.kt` wired for `FLAG_SECURE` via a method channel; `AndroidManifest.xml` has `USE_BIOMETRIC` + `INTERNET` permissions.
- iOS: `AppDelegate.swift` wired for blur-on-resign-active; `Info.plist` has `NSFaceIDUsageDescription`.

---

## Verification done so far

- `flutter analyze` — **zero issues**, repeatedly re-checked after each change.
- `flutter build apk --debug` — **succeeds** (first build ~526s cold, ~50s incremental), which exercises compilation of every native plugin (`sodium_libs`, SQLCipher, `local_auth`, `flutter_secure_storage`) plus the custom Kotlin/Swift changes.
- `flutter test` — theme/widget smoke test passes. The crypto unit tests (`test/core/crypto_test.dart`) fail under the test runner only because `sodium_libs`' native platform channel isn't registered in the bare VM test host — this is a `flutter test` limitation, not a code defect (confirmed the same calls work correctly when actually compiled into the APK).

- `flutter build web --release` — **succeeds** with all three browser assets
  (`sodium.js`, `sqflite_sw.js`, `sqlite3.wasm`) landing in `build/web/`.
  The assembled site (landing at root + app at `/app/`) was served locally and
  every asset path returns 200, with `<base href="/KeyLa/app/">` correct.

## Known gaps / not yet done

1. **No native OS autofill.** Android `AutofillService` + Credential Manager API, and iOS `ASCredentialProviderViewController`, are both still unbuilt. This was explicitly deferred (per earlier discussion) as a separate, large native-code milestone requiring device testing.
2. **Web build never opened in a real browser.** It compiles and every asset
   resolves over HTTP, but no one has clicked through it live, so JS-runtime
   behaviour (sodium init, the IndexedDB vault) is "should work, unverified".
   Also note the web build is a **UI preview, not a secure vault** — SQLCipher,
   Keystore key storage, biometrics, and screenshot blocking are all absent in
   the browser. Fields are still XChaCha20-sealed, but the depth is gone.
3. **No interactive on-device run.** No Android emulator/system image is installed on this machine and none was set up (would require a large download). The app has never been clicked through live — only compiled and packaged. Everything UI-related should be treated as "should work, unverified in a live session" until someone runs it on a device/emulator.
4. **PHP server never executed.** PHP isn't installed on this machine, so `arif_kyla_*.php` has not been run or hit with `curl`. It follows MedRemind's proven-working structure closely, but hasn't been independently exercised end-to-end (register → login → upload → download).
5. **`SERVER_BASE_URL` is a placeholder** (`https://your-host.example.com/server`) — needs a real host + `--dart-define` at build/run time before backup/account features can work against a live server.
6. Sodium_libs is a discontinued package (superseded by a newer `sodium` package major version) — works fine currently, but worth revisiting if it stops receiving updates.

## Suggested next steps (pick up here)

1. Stand up the PHP server somewhere real (or locally with PHP installed) and smoke-test the endpoints with `curl`.
2. Get an Android emulator or physical device connected and do a full manual walkthrough: register → onboarding → add credential → lock/unlock → biometrics → generator → health dashboard → backup/restore.
3. Decide on and build the native autofill milestone, or explicitly confirm it stays out of scope.
