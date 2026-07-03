# Password Manager App — Build Specification

**Document type:** Product & engineering spec for an AI coding agent
**Deliverable:** A cross-platform mobile app that automatically captures, stores, and auto-fills login passwords, with a best-in-class UI/UX.
**Status:** Ready to build. Where a decision is left open, a sensible default is marked `DEFAULT:` — change it if you prefer.

---

## 1. Product Overview

A secure mobile password manager. It automatically **saves** credentials when the user logs into an app or website, **auto-fills** them on return, **generates** strong passwords, and keeps everything encrypted behind a master password plus biometric unlock.

The core promise to the user: *"You never type or remember a password again, and only you can ever read your vault."*

### The one thing that must be true
This is a security product first and a convenience product second. A beautiful app that leaks passwords is a failure. Encryption, key handling, and use of the official OS autofill APIs are **non-negotiable** and are specified precisely below. Do not shortcut them.

---

## 2. Goals & Non-Goals

**Goals**
- Auto-save login credentials the moment a user signs in somewhere.
- Auto-fill credentials on return, with one tap / biometric confirm.
- Zero-knowledge encryption: the app (and any future backend) can never read plaintext passwords.
- Fast, delightful, low-friction UI that a non-technical person trusts instantly.
- Offline-first. The vault works with no network.

**Non-Goals (v1)**
- Cloud sync across devices (design the data layer so it can be added later, but ship local-only first).
- Desktop/browser extension.
- Password sharing between users.
- Enterprise/team features.

---

## 3. Target User

Everyday phone users who reuse weak passwords and are tired of "forgot password" flows. They are not security experts. The UX must assume **zero technical knowledge** and explain security in plain, calm language.

---

## 4. Platform & Tech Stack

- **Framework:** `DEFAULT:` React Native (Expo bare workflow) for one codebase across iOS + Android. Flutter is an acceptable alternative — if chosen, keep the same architecture.
- **Language:** TypeScript (strict mode on).
- **Local storage:** Encrypted SQLite (e.g. SQLCipher via `op-sqlite` / `react-native-quick-sqlite`). Never store plaintext credentials in AsyncStorage or plain SQLite.
- **Secure key storage:** iOS Keychain / Android Keystore (via `react-native-keychain`) for the wrapped encryption key and biometric-gated secrets.
- **Crypto:** A vetted, native-backed library (libsodium via `react-native-libsodium`, or `react-native-quick-crypto`). **Do not hand-roll crypto.**
- **Biometrics:** `expo-local-authentication` (Face ID / Touch ID / Android biometric).
- **State:** Zustand or Redux Toolkit. Keep decrypted secrets out of any persisted store.
- **Navigation:** React Navigation (native stack + bottom tabs).

### OS integration — this is how "automatic" saving actually works
You **cannot** and must not read other apps' password fields directly (that is spyware and the OS forbids it). The legitimate, required approach is the platform autofill frameworks:

- **Android:** Implement an `AutofillService` (Android Autofill Framework) and integrate the **Credential Manager API**. This lets the OS offer to save credentials on login and fill them on return.
- **iOS:** Implement an **AutoFill Credential Provider extension** (`ASCredentialProviderViewController`) and register with the Password AutoFill system. Support the **Associated Domains** / passkey flows where possible.

The main app manages the vault; the OS extensions do the capture and fill. Build the extensions as first-class deliverables, not afterthoughts.

---

## 5. Security Architecture (implement exactly)

**Master password → encryption key**
- Derive a key from the master password using **Argon2id** (preferred) or PBKDF2-HMAC-SHA256 with a high iteration count if Argon2 is unavailable. Use a per-user random salt (≥16 bytes).
- The derived key encrypts a randomly generated **vault key** (envelope encryption). Only the wrapped vault key is stored.

**Encryption**
- Encrypt each credential record with **XChaCha20-Poly1305** (or AES-256-GCM) using the vault key. Unique nonce per record. Store the auth tag.
- The vault key lives in memory only while unlocked, and is wrapped at rest.

**Unlock**
- Master password unlock always available.
- Biometric unlock is a convenience layer: store a biometric-gated copy of the wrapped key in Keychain/Keystore, released only after successful biometric auth.

**Zero-knowledge**
- Plaintext passwords never leave the device unencrypted and are never logged, never sent to analytics, never placed in crash reports.
- Auto-lock the vault after inactivity (`DEFAULT:` 60s) and on app backgrounding. Clear decrypted secrets from memory on lock.
- Blur/obscure the app preview in the OS app switcher.
- Disable screenshots on sensitive screens (Android `FLAG_SECURE`; iOS obscure on `willResignActive`).

**Clipboard**
- If a password is copied, auto-clear the clipboard after `DEFAULT:` 30s and never persist clipboard history.

**Recovery**
- Master password is unrecoverable by design (zero-knowledge). During onboarding, offer an optional **recovery kit** (a printable/secure recovery code) and make the "no reset possible" tradeoff explicit and unmissable.

---

## 6. Feature Set

### 6.1 Onboarding & master password
- Warm 3-screen intro explaining what the app does and the security model in plain language.
- Create master password with a **live strength meter** and clear requirements.
- Set up biometric unlock (skippable).
- Offer recovery kit generation.

### 6.2 Vault
- List all saved credentials: site/app name, username, favicon/app icon, last-used.
- Add, view, edit, delete a credential.
- Password field masked by default with a reveal toggle (revealed value auto-hides after a few seconds).
- Copy username / copy password (with auto-clear clipboard).
- Notes field, optional; category/tag; favorite flag.

### 6.3 Auto-save (the headline feature)
- When the OS detects a login, prompt: *"Save this password to [App name]?"* with app icon and username shown.
- One-tap save. If the domain/app already has an entry, offer **Update** instead of creating a duplicate.
- Detect and offer to fix reused or weak passwords over time.

### 6.4 Auto-fill
- On a login screen, the OS surfaces matching credentials from the extension.
- User confirms with biometric/tap; the fields fill.
- Handle multiple matches gracefully (pick which account).

### 6.5 Password generator
- Generate strong passwords: length slider (8–64, `DEFAULT:` 20), toggles for uppercase/lowercase/numbers/symbols, avoid-ambiguous-characters option.
- Optional passphrase mode (word-based).
- "Use this password" writes it straight into the credential being created.

### 6.6 Security dashboard ("Password Health")
- Summary score plus lists: weak passwords, reused passwords, old passwords, and (if a breach API is added later) exposed passwords.
- Each item is tappable and routes to a guided fix.

### 6.7 Search & organization
- Instant fuzzy search across site name and username.
- Filter by category/favorites. Sort by name / recently used.

### 6.8 Settings
- Change master password, manage biometrics, auto-lock timeout, clipboard clear timeout, theme, export/import (encrypted only), delete all data, view recovery kit.

---

## 7. Data Model

```
Credential {
  id: uuid
  title: string            // "Netflix", "gmail.com"
  domain: string?          // for web match
  androidPackage: string?  // for app match, e.g. com.netflix.mediaclient
  username: string         // ENCRYPTED
  password: string         // ENCRYPTED
  notes: string?           // ENCRYPTED
  category: string?
  isFavorite: boolean
  strength: enum(weak, fair, strong)  // derived, not encrypted
  createdAt, updatedAt, lastUsedAt: timestamp
}

VaultMeta {
  wrappedVaultKey: bytes
  kdfSalt: bytes
  kdfParams: json
  version: int
}
```

Encrypted fields are stored as ciphertext + nonce + auth tag. The `strength` flag is derived locally and is safe to keep unencrypted for the health dashboard, but never store the actual password unencrypted to compute it.

---

## 8. UI/UX Design System

The user asked specifically for **best-in-class UI/UX**. This section is the design contract.

### 8.1 Design principles
1. **Calm confidence.** Security apps feel scary when done wrong. Rounded shapes, generous whitespace, soft motion, plain language. Never use alarming red unless something is genuinely wrong.
2. **One primary action per screen.** The user always knows the single most important thing to tap.
3. **Trust made visible.** Small, honest cues ("Encrypted on this device", lock icons that mean something) — not fake padlock theater.
4. **Speed is a feature.** Unlock → fill in under two taps. No spinners where instant is possible.
5. **Respectful defaults.** Biometrics on, strong generator on, auto-lock on.

### 8.2 Visual language
- **Aesthetic:** modern, soft-neumorphic-lite / clean fintech. Depth via subtle shadows and layering, not skeuomorphism.
- **Color palette (`DEFAULT:`, adjust freely):**
  - Primary: deep indigo `#4F46E5`
  - Primary-dark: `#3730A3`
  - Accent / success: emerald `#10B981`
  - Warning: amber `#F59E0B`
  - Danger: rose `#F43F5E` (used sparingly)
  - Neutral surface (light): `#FFFFFF` / `#F5F6FA`
  - Neutral surface (dark): `#0F1117` / `#1A1D27`
  - Text primary/secondary with proper contrast in both themes.
- **Full dark mode** as a first-class theme, following the system by default.
- **Typography:** one clean humanist sans (Inter or SF Pro / Roboto system default). Sizes: display 28–32, title 20–22, body 15–16, caption 13. Bold for numbers and titles, regular for body. Never use more than two weights on a screen.
- **Shape:** 16px corner radius on cards, 12px on inputs, pill buttons. 8pt spacing grid.
- **Iconography:** consistent line-icon set (Lucide / Phosphor). App/site favicons for entries with a colored monogram fallback.

### 8.3 Core components
- **Credential card:** icon + title + masked username, swipe actions (copy, edit, delete), tap to expand.
- **Primary button:** full-width pill, indigo, subtle press-scale.
- **Input:** floating label, clear focus ring, inline validation, reveal toggle for secret fields.
- **Strength meter:** animated segmented bar, color shifts weak→strong, plain-language label.
- **Bottom sheet:** used for add/save prompts and confirmations — feels native and fast.
- **Empty states:** friendly illustration + one-line explanation + primary CTA.

### 8.4 Motion & micro-interactions
- Unlock: smooth shield/lock "open" animation (200–300ms, ease-out). Never gratuitous.
- Save confirmation: quick checkmark + light haptic.
- Copy: toast "Copied — clears in 30s" + haptic tick.
- List: subtle staggered fade-in on load. Skeleton loaders, never blank flashes.
- Respect reduced-motion settings.

---

## 9. Screen-by-Screen Spec

1. **Splash / Lock** — logo, biometric prompt on launch, master-password fallback. Auto-focuses biometric.
2. **Onboarding (3 screens)** — what it does, security model, create master password (+ strength meter), biometric setup, recovery kit.
3. **Vault Home** — search bar, favorites row, credential list, floating **+** to add. Password Health chip at top showing score.
4. **Credential Detail** — icon, title, username (copy), password (reveal + copy), notes, category, last used, edit/delete.
5. **Add / Edit Credential** — title, username, password (with **Generate** button opening the generator), notes, category, save.
6. **Password Generator** — big generated password display, length slider, toggles, regenerate, "Use this password", copy.
7. **Auto-save Prompt (bottom sheet)** — app icon, detected username, Save / Update / Not now.
8. **Password Health** — score ring, grouped issue lists, tap-to-fix.
9. **Settings** — as listed in 6.8.

Provide light + dark mockups for at least: Lock, Vault Home, Credential Detail, Generator, Auto-save Prompt.

---

## 10. Key User Flows

**First run:** Splash → Onboarding → create master password → biometrics → recovery kit → empty Vault Home with a friendly "Add your first password" CTA.

**Auto-save:** User logs into an app → OS detects submission → bottom-sheet "Save to [App]?" → one tap → success haptic → entry appears in vault.

**Auto-fill:** User opens a login screen → OS shows matching credential above keyboard → tap → biometric confirm → fields fill.

**Manual add with generator:** Vault Home → **+** → title + username → **Generate** → adjust → Use → Save.

**Unlock after inactivity:** App auto-locked → biometric prompt → vault opens instantly.

---

## 11. Accessibility

- WCAG AA contrast in both themes.
- Full screen-reader labels (VoiceOver/TalkBack), especially on masked fields ("password, hidden, double-tap to reveal").
- Dynamic type / font scaling support; layouts must not break at large text sizes.
- Minimum 44×44pt tap targets.
- Reduced-motion and reduced-transparency support.

---

## 12. Non-Functional Requirements

- Cold start to unlock screen < 1.5s on mid-range devices.
- Vault open (decrypt + render 200 entries) < 300ms.
- No plaintext secret ever in logs, analytics, crash reports, or backups.
- Analytics (if any) must be privacy-preserving and exclude all vault contents; make it opt-in.
- Offline-first: every core feature works with no network.
- Test coverage on the crypto and unlock paths is mandatory.

---

## 13. Suggested Build Order (milestones)

1. **M1 — Secure core:** crypto layer, key derivation, encrypted SQLite, master-password unlock. (No UI polish yet.)
2. **M2 — Vault CRUD + design system:** components, theming, add/edit/view/delete, search.
3. **M3 — Biometrics + auto-lock + clipboard safety.**
4. **M4 — Password generator + Password Health dashboard.**
5. **M5 — OS autofill:** Android AutofillService + Credential Manager; iOS AutoFill extension. Auto-save + auto-fill flows.
6. **M6 — Onboarding, recovery kit, settings, polish, motion, accessibility pass.**

---

## 14. Acceptance Criteria (definition of done)

- [ ] No plaintext password is ever written to disk, logs, or network.
- [ ] Vault locks on background and after the configured timeout; secrets cleared from memory.
- [ ] Biometric and master-password unlock both work; biometric never bypasses encryption.
- [ ] Android Autofill and iOS AutoFill extensions save and fill credentials on real login screens.
- [ ] Auto-save offers Update (not duplicate) for existing domains/apps.
- [ ] Generator produces cryptographically random passwords honoring all options.
- [ ] Clipboard auto-clears after the configured timeout.
- [ ] Full light + dark themes; AA contrast; screen-reader labels on all interactive elements.
- [ ] App preview obscured in the switcher; screenshots blocked on sensitive screens.
- [ ] Crypto and unlock paths covered by automated tests.

---

## 15. Notes for the building agent

- Use only the **official OS autofill/credential APIs** for capturing and filling passwords. Do not attempt to read other apps' input fields, use accessibility services to scrape passwords, or any keylogging approach — those are prohibited by the platforms, will get the app rejected, and are unsafe for users.
- Do not implement your own cryptographic primitives; use the vetted libraries named in §4.
- Treat every `DEFAULT:` as changeable, but treat everything in §5 (Security Architecture) as fixed requirements.
