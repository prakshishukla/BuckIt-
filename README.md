# BuckIt

**A shared bucket list app where friends complete challenges, prove it with a photo, and unlock real discounts from brands.**

Native iOS app in SwiftUI (iOS 17+, Xcode 16+). Hackathon demo build: there's no backend, and all data is local and seeded.

---

## Setup

1. Open `BuckIt.xcodeproj` in Xcode 16 or later.
2. Pick the **BuckIt** scheme and an **iPhone 16 Pro** Simulator.
3. Press **⌘R**.

You don't need packages, keys or accounts. Without a Gemini key, the app uses the offline demo verifier.

To run on a physical iPhone, select the **BuckIt** target, open **Signing & Capabilities**, and choose your (free) Apple ID team. If the bundle ID `com.dubhacks26.buckit` is taken, change it to something unique.

## The 60-second demo script

| # | Do this | You'll see |
|---|---|---|
| 1 | Launch → **Continue as Buck It** | Animated bucket logo, "Kick the bucket list. Together." |
| 2 | Preferences: City **Seattle**, Season **Summer** → **Next** | These values are pre-filled. Other cities show as "coming soon". Commitment isn't asked at setup; it can be changed later from Profile. |
| 3 | **Allow access** → **Add** Dylan/Maya → **Invite** Sam → **Done** | Fake contact sync. On the Simulator, Invite copies the link and shows a toast. On a phone, it opens Messages. |
| 4 | Home | Friends' posts with photos, reactions and comments, plus group filter chips. Priya's post carries a **Sponsored: Patagonia** tag on the photo. |
| 5 | **Challenges → Sponsored → Patagonia "Hike 5+ miles"** | Two dropdowns filter by time commitment and activity type. On iOS 18+, the card zooms into the detail screen. |
| 6 | Read the criteria → **Submit** | The reward card stays locked and blurred. |
| 7 | **Use demo photo** (Simulator) or snap a photo, then a selfie (phone). Tag a friend → **Post** | The location and time chips fill in automatically. |
| 8 | Verification | The criteria tick off one by one, then a green check draws in with confetti and a haptic. |
| 9 | Coupon reveal | The card flips to "15% off one item" at Patagonia, then "Saved to Wallet". Tap **Done**. |
| 10 | Home → **Challenges** → **Profile** | The post is at the top of the feed, and the Patagonia card has dropped off the Sponsored list. On Profile, the water bucket rises one level with a splash: "1/10 drops this season". |
| 11 | **Profile → Wallet** | The coupon shows its code (e.g. `PATA-7XK2QM`), a QR code, its expiry, and a "Mark as used" button. |

## Demo-day setup

1. Open `BuckIt.xcodeproj`, choose the **iPhone 16 Pro** Simulator, and press ⌘R.
2. Check that the scheme's default location is `Seattle.gpx`: **Product → Scheme → Edit Scheme → Run → Options → Default Location**. It's preset to Discovery Park. If Xcode shows "None", pick `Seattle.gpx` from the list. If no location is available, the app uses "Discovery Park, Seattle".
3. **Profile → Settings → Reset demo** before presenting. This returns the app to the sign-in screen with a clean state.
4. On the Simulator, use **Use demo photo** at the camera step. On a real iPhone connected by cable and signed with a free Apple ID team, the live back-then-front BeReal-style camera works.
5. For a bigger screen, open QuickTime → **New Movie Recording** and select the iPhone to mirror a physical device. You can also just present the Simulator window.

**More to show:**
- **Challenges → My Groups** lists only your groups: Seattle Summer Crew 🌊, Trail Squad 🥾 and Island Hoppers ⛴️. Tap one to see its list in sections (Sponsored picks, Local, Parks & Adventures). Tasks you've finished disappear, and each task shows avatars of the members who have done it.
- **Profile → My Groups → a group** shows the entire list (finished tasks included), all current members, and a **+** button at the top right to add people.
- To start from an empty feed instead, turn off **Profile → Settings → Seed demo feed**.

## Real Gemini verification (Best Use of Gemini)

The verifier sits behind a protocol in `BuckIt/Services/VerificationService.swift`, so you can swap the mock for the real one:

- `MockVerificationService` is the default when no key is set. It waits about a second and passes every criterion. The screen then says **"Verifying your proof…"**.
- `GeminiVerificationService` is used when a key is present. It sends the JPEG (base64) plus the challenge title, description and criteria to Gemini's `generateContent` REST endpoint and asks for strict JSON:
  `{ "matches": bool, "criteria": [{ "criterion", "met", "why" }], "confidence": 0-1 }`.
  On-device checks are added for **timestamp recency** (under 48 h) and **location** (within 150 km of Seattle). The screen says **"Verifying with Gemini…"** and shows each criterion with Gemini's reason, plus the confidence score.

To enable it:

```sh
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # gitignored
# then edit Config/Secrets.xcconfig:
#   GEMINI_API_KEY = <your key from https://aistudio.google.com/apikey>
#   GEMINI_MODEL   = gemini-flash-latest     (optional; any vision-capable model id)
#   FORCE_VERIFY   = YES                     (default; see below)
```

Clean-build (⇧⌘K) and run. **Profile → Settings → Verification** shows which mode is active.

**`FORCE_VERIFY`** (default `YES`) keeps the stage demo safe: the submission always verifies and mints the coupon. If Gemini is unreachable, the app falls back to the demo result. Per-criterion results are still shown exactly as Gemini returned them, so a judge can see a real ✗ if the photo doesn't fit. Set it to `NO` to make Gemini's verdict decide. A failed check then offers "Retake photo" or "Post without reward".

> The key travels through `Info.plist` into the app bundle, which is fine for a hackathon. A production app would proxy Gemini calls through a server so the key never ships to clients.

## Project layout

```
BuckIt.xcodeproj            Xcode 16 project (synchronized folder, so new files are picked up automatically)
Config/
  BuckIt.xcconfig           GEMINI_* / FORCE_VERIFY defaults; includes Secrets.xcconfig if present
  Secrets.example.xcconfig  template → copy to Secrets.xcconfig (gitignored)
  Info.plist                privacy usage strings + config keys
BuckIt/
  BuckItApp.swift           app entry, RootView (sign-in → onboarding → tabs), MainTabView
  AppStore.swift            @Observable state, JSON persistence, all actions
  Models/                   User, BuckGroup, Challenge/Sponsor/RewardTemplate, Coupon, Post/Comment, enums
  Data/SeedData.swift       every hardcoded user, group, challenge, reward and demo post
  Services/                 VerificationService (mock + Gemini), LocationService, CameraService, PhotoStore
  Views/
    Onboarding/             SignInView, PreferencesView (+ OnboardingFlow), InviteFriendsView
    Home/                   FeedView, PostCardView (+ DualPhotoView), CommentsSheet
    Challenges/             ChallengesView, ChallengeCardView, ChallengeDetailView
    Capture/                CaptureFlowView, CaptureView, CapturePreviewView, VerificationView, CouponRevealView (+ PostedView)
    Profile/                ProfileView, WaterBucketView, WalletView, CouponCardView, GroupsView (+ CreateGroupView)
    Components/             Theme, SponsorBadge (+ SponsorArt), ChipView, AvatarView, ConfettiView, EmptyStateView, Effects
  Resources/
    Assets.xcassets         app icon, named colors (light + dark), demo + feed photos
    Seattle.gpx             simulated location (Discovery Park)
```

Design: Playfair Display for titles and DM Sans for everything else (both SIL Open Font License, see `Licenses/`), with a palette of #05668D, #028090 and #513B56 (primary) plus #B0A3D4 and #F0F3BD (secondary). Colors live in `Assets.xcassets` as `Brand*` color sets with dark-mode variants. Fonts are set up in `Views/Components/Theme.swift`.

Debug builds accept launch arguments for jumping past onboarding: `-skipOnboarding`, `-tab home|challenges|profile`, and `-openGroup <name prefix>`.

Notes:
- The group model is named `BuckGroup` so it doesn't shadow SwiftUI's `Group`. The category enum is `ChallengeCategory` so it doesn't clash with the Objective-C runtime's `Category`.
- State is saved as JSON in the app's Documents directory (`buckit-demo-state.json`), with photos under `Documents/photos/`. It survives relaunches. **Reset demo** clears both.
- The bundled demo and feed images are original illustrations generated for this project. Swap them for the team's own photos by replacing the files in `Assets.xcassets`, keeping the same names.
- Sponsor badges use SF Symbols and brand colors. Each `Sponsor` has a `logoAsset` slot: add an image with that name to the asset catalog, only with the brand's permission, and the badge will use it. Every coupon carries a **DEMO** tag.
