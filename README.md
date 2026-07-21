# Keyla

**Your passwords, sealed.** A zero-knowledge password manager built in Flutter —
Argon2id + XChaCha20-Poly1305 encryption, an encrypted SQLCipher vault, a
password generator, and a password health dashboard. The master password never
leaves the device, and the backend only ever stores opaque ciphertext.

🔗 **Live web demo:** https://theobsidianeye-arif-foysal.github.io/KeyLa/

📄 **Design spec:** [`keyla_v1/docs/password-manager-app-spec.md`](keyla_v1/docs/password-manager-app-spec.md)
· **Build status:** [`keyla_v1/docs/progress-report.md`](keyla_v1/docs/progress-report.md)

---

## Repository layout

```
Keyla/
├── keyla_v1/               Flutter app source
├── server/                 ARIF(KyLa) PHP + SQLite backend (auth + encrypted vault blobs)
├── landing/                Marketing landing page (static, no build step)
├── scripts/                build_server_web.ps1 — packages the self-hosted web build
└── .github/workflows/      CI: builds the web app and deploys it to GitHub Pages
```

## Running locally

```bash
cd keyla_v1
flutter pub get
flutter run                       # native (Android/iOS)
flutter run -d chrome             # web
```

Point the app at your backend at build/run time:

```bash
flutter run --dart-define=SERVER_BASE_URL=https://your-host.example.com/server
```

The server (`server/`) is plain PHP + PDO/SQLite — deploy it to any PHP host.
The database file is created on first request.

---

## Web deployments

There are two, both with the **landing page at the root and the Flutter app
under `/app/`**.

### 1. GitHub Pages (automatic)

`.github/workflows/deploy-web.yml` runs on every push to `main` that touches
`keyla_v1/`, `landing/`, or the workflow itself. It builds with
`--base-href /KeyLa/app/` and publishes:

| URL | What |
|---|---|
| `https://theobsidianeye-arif-foysal.github.io/KeyLa/` | Landing page |
| `https://theobsidianeye-arif-foysal.github.io/KeyLa/app/` | Flutter web app |

### 2. Self-hosted (manual)

```powershell
./scripts/build_server_web.ps1 `
  -BasePath '/ARIF(KyLa)/' `
  -ServerBaseUrl 'https://ruetandroiddevelopers.com/ARIF(KyLa)/server'
```

Produces `build/server_web/` and `Keyla_upload.zip`. Extract the zip into the
folder served at `-BasePath` — the landing page lands at the root and the app
at `app/`.

### Web build prerequisites

Two sets of browser assets must exist in `keyla_v1/web/` (both are committed,
but regenerate them after a dependency bump):

```bash
dart run sodium_libs:update_web          # sodium.js — else the app hangs at splash
dart run sqflite_common_ffi_web:setup    # sqflite_sw.js + sqlite3.wasm
```

## ⚠️ Web build limitations

The browser build is a **UI preview, not a secure vault.** Three of the app's
security layers are native-only and have no browser equivalent:

| Native | On web |
|---|---|
| SQLCipher whole-file DB encryption (`sqflite_sqlcipher`) | Plain IndexedDB-backed sqflite via `sqflite_common_ffi_web` |
| Keystore/Keychain-held DB key (`path_provider` paths) | No filesystem; DB key still in `flutter_secure_storage` (browser-grade only) |
| Biometric unlock (`local_auth`) | Unavailable — falls back to master password |
| Screenshot blocking / app-switcher blur | No-op |

Credential fields are still XChaCha20-Poly1305 sealed by the app before they
are written, so browser storage holds ciphertext rather than plaintext — but
the defence-in-depth layers above are missing. **Use the Android app for real
passwords.**
