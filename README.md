# BuckIt

**A shared bucket list app where friends complete challenges, prove it with a photo checked by Gemini, and unlock real discounts from brands.**

Native iOS app in SwiftUI (iOS 17+, Xcode 16+). Hackathon demo build: there's no backend, and all data is local and seeded.

---

## Setup

1. Open `BuckIt.xcodeproj` in Xcode 16 or later.
2. Pick the **BuckIt** scheme and an **iPhone 16 Pro** Simulator.
3. Press **⌘R**.

You don't need packages or accounts. A Gemini key is optional (see below); without one, photo checks run in an offline demo mode.

To run on a physical iPhone, select the **BuckIt** target, open **Signing & Capabilities**, and choose your (free) Apple ID team. If the bundle ID `com.dubhacks26.buckit` is taken, change it to something unique.

## The 60-second demo script

| # | Do this | You'll see |
|---|---|---|
| 1 | Launch → **Continue as Buck It** | Animated bucket logo and the tagline. |
| 2 | Preferences: City **Seattle**, Season **Summer** → **Next** | These values are pre-filled. Other cities show as "coming soon". Commitment isn't asked at setup; it can be changed later from Profile. |
| 3 | **Allow access** → **Add** Dylan/Maya → **Invite** Sam → **Done** | Fake contact sync. Added friends join your first list, Seattle Summer 2026. On the Simulator, Invite copies the link and shows a toast. On a phone, it opens Messages. |
| 4 | Home | Friends' posts with real Seattle photos, reactions and comments, and list filter chips. Headers name everyone who did it together ("Maya and Priya"); tap a name to see that person's profile. Priya's post carries a **Sponsored: Patagonia** tag on the photo. |
| 5 | **Challenges → Sponsored → Patagonia "Hike 5+ miles"** | Two dropdowns filter by time commitment and activity type. **Add to list** puts it on any of your lists that don't have it yet. |
| 6 | **Post it** | The camera opens. |
| 7 | **Use demo photo** (Simulator) or snap a photo, then a selfie (phone). Tag a friend → **Post** | The location and time chips fill in automatically. |
| 8 | Verification | "Verifying with Gemini…": Gemini checks the photo against the item, and the app checks when and where it was taken. Each check ticks off with Gemini's reason, then a green check with confetti. |
| 9 | Coupon reveal | The card flips to "15% off one item" at Patagonia, then "Saved to Wallet". Tap **Done**. |
| 10 | Home → **Challenges** → **Profile** | The post is at the top of the feed, and the Patagonia card has dropped off the Sponsored list. The moment the post goes up, the bucket (seeded at 9/10, one colored layer per activity type) gets its 10th layer and **overflows** on whatever screen you're on: water in the bucket's colors floods the screen with confetti, and Profile shows a new empty Bucket #2. |
| 11 | **Profile → Wallet** | The coupon shows its code (e.g. `PATA-7XK2QM`), a QR code and its expiry. **Mark as used** asks what you bought and can share it on your post. |
| 12 | **Sponsor View** tab | Patagonia's dashboard: who it targets (≥60% Outdoors), how many people that reaches, and the funnel. Your own steps from the demo count live. The purchase you just shared is at the top of "What people bought". |

## Demo-day setup

1. Open `BuckIt.xcodeproj`, choose the **iPhone 16 Pro** Simulator, and press ⌘R.
2. Check that the scheme's default location is `Seattle.gpx`: **Product → Scheme → Edit Scheme → Run → Options → Default Location**. It's preset to Discovery Park. If Xcode shows "None", pick `Seattle.gpx` from the list. If no location is available, the app uses "Discovery Park, Seattle".
3. **Profile → Settings → Reset demo** before presenting. This returns the app to the sign-in screen with a clean state.
4. On the Simulator, use **Use demo photo** at the camera step. On a real iPhone connected by cable and signed with a free Apple ID team, the live back-then-front BeReal-style camera works.
5. For a bigger screen, open QuickTime → **New Movie Recording** and select the iPhone to mirror a physical device. You can also just present the Simulator window.

**More to show:**
- **Home → camera icon** (top right): take a photo first, then choose which list and item it's for, and post it straight to the feed.
- **Challenges → My Lists** shows only lists you're on: Seattle Summer 2026 🌊, PNW Trails 🥾, Islands & Water ⛴️ and Eat, Drink & Events 🎟️. Tap one to see what's left, in sections. Items you've finished disappear, and each item shows avatars of the people on the list who've done it.
- **Profile → My Lists → a list** shows everything, with completed items at the bottom, and all the people on the list. **+** at the top right adds items (from the catalog or your own idea), and **Add people** in the Members section adds friends. **Create list** starts a new one.
- **Friend profiles** (tap a name on a post, a list member, or a friend on a challenge) show only the lists you share, up to three things they've done on each, and **See all** to open the list.
- **Activity types** (Outdoors, Big trips, Small trips, Food, Local events, Culture, Entertainment, With friends) are the same on every item and in every filter. Each one has a water color; change them under **Profile → Bucket colors**.
- **Completed lists:** once you've done everything on a list, it disappears from Challenges and moves to **Completed lists** at the bottom of Profile → My Lists. You can still open it to follow everyone's progress (each member shows "done/total"). Spring Weekend 🌸 is seeded as completed.
- **✨ Ideas** (Profile → a list → **+** → ✨ Ideas): describe a mood ("rainy day", "cheap eats"), and Gemini suggests items for that list. Tick the ones you want and add them.
- **Sponsor View** (demo-only tab): pick a sponsor to see its audience rule, a slider that previews reach at other thresholds, which real people qualify, the funnel (added to list → submitted, waiting to use the coupon → redeemed and used), what people bought, top neighborhoods, and **Suggest campaigns** (Gemini proposes the next sponsored challenge from the funnel data).
- To start from an empty feed instead, turn off **Profile → Settings → Seed demo feed**.

## Gemini (Best Use of Gemini)

BuckIt uses Gemini in three places, all through `BuckIt/Services/GeminiClient.swift`:

- **Photo verification** for every post (below).
- **List-item ideas** for people who can't think of what to add (`IdeaGenerator`).
- **Campaign ideas** for sponsors in Sponsor View.

Without a key, each one falls back to clearly labeled offline demo content.

### Photo verification

Every post, sponsored or not, goes through `BuckIt/Services/VerificationService.swift`:

1. **Gemini vision**: the JPEG (base64), the item's title, description and place, plus the photo's metadata, go to Gemini through the Interactions API (`POST /v1beta/interactions`, which new API keys use). Gemini answers in strict JSON: `{ "matches": bool, "criteria": [{ "criterion", "met", "why" }], "confidence": 0-1 }`. Sponsored items use the sponsor's criteria; other items are checked for "Photo shows: <item>" and "Looks like a real photo taken there".
2. **On-device checks**: **Taken recently** (within 7 days) and **Taken near** the item (within 150 km of Seattle, 400 km for Big trips). They use the photo's own EXIF GPS and timestamp when it has them (library photos), otherwise the phone's location and the capture time. Each row says which source it used.

The screen shows every check with Gemini's reason and the confidence. If a check fails, you can **Retake** or **Post anyway** (unverified posts don't unlock sponsor rewards).

To enable it:

```sh
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # gitignored
# then edit Config/Secrets.xcconfig:
#   GEMINI_API_KEY = <your key from https://aistudio.google.com/apikey>
#   GEMINI_MODEL   = gemini-3-flash-preview        (optional; the app falls back to lighter models if busy)
#   FORCE_VERIFY   = YES                     (optional stage safety net: always pass)
```

Clean-build (⇧⌘K) and run. **Profile → Settings → Photo check** shows which mode is active. Without a key, the screen says "Verifying (offline demo)…" and the photo checks pass automatically; the time and location checks still run for real.

> The key travels through `Info.plist` into the app bundle, which is fine for a hackathon. A production app would proxy Gemini calls through a server so the key never ships to clients.

## Project layout

```
BuckIt.xcodeproj            Xcode 16 project (synchronized folder, so new files are picked up automatically)
Config/
  BuckIt.xcconfig           GEMINI_* / FORCE_VERIFY defaults; includes Secrets.xcconfig (gitignored) if present
  Secrets.example.xcconfig  template → copy to Secrets.xcconfig
  Info.plist                privacy usage strings, bundled fonts, config keys
BuckIt/
  BuckItApp.swift           app entry, RootView (sign-in → onboarding → tabs), MainTabView
  AppStore.swift            @Observable state, JSON persistence, all actions
  Models/                   User, BuckList, Challenge/Sponsor/RewardTemplate, Coupon, Post/Comment, enums
  Data/SeedData.swift       every hardcoded user, list, challenge, reward and demo post
  Data/SeedPictures/        photos for the Seattle items and demo posts
  Services/                 GeminiClient (+ IdeaGenerator), VerificationService (EXIF evidence), LocationService, CameraService, PhotoStore
  Views/
    Onboarding/             SignInView, PreferencesView (+ OnboardingFlow), InviteFriendsView
    Home/                   FeedView, PostCardView (+ DualPhotoView), CommentsSheet
    Challenges/             ChallengesView, ChallengeCardView, ChallengeDetailView
    Capture/                CaptureFlowView, CaptureView, CapturePreviewView (+ list/item picker), VerificationView, CouponRevealView (+ PostedView)
    Lists/                  ListDetailView, ListSheets (AddItemSheet, AddMembersSheet, CreateListView, ListsView)
    Profile/                ProfileView, FriendProfileView, WaterBucketView (layered water), BucketOverflowView (+ BucketColorsSheet), WalletView, CouponCardView
    Sponsor/                SponsorView (audience, funnel, purchases, Gemini campaign ideas)
    Components/             Theme, SponsorBadge (+ SponsorArt), ChipView, AvatarView, ConfettiView, EmptyStateView, Effects
  Resources/
    Assets.xcassets         app icon, named colors (light + dark), demo selfie
    Seattle.gpx             simulated location (Discovery Park)
```

Design: Playfair Display for titles and DM Sans for everything else (both SIL Open Font License, see `Licenses/`), with a palette of #05668D, #028090 and #513B56 (primary) plus #B0A3D4 and #F0F3BD (secondary). Colors live in `Assets.xcassets` as `Brand*` color sets with dark-mode variants. Fonts are set up in `Views/Components/Theme.swift`.

Debug builds accept launch arguments for jumping past onboarding: `-skipOnboarding`, `-tab home|challenges|profile|sponsor`, `-openList <name prefix>` (Challenges), `-openProfileList <name prefix>` and `-openFriend <first name>` (Profile), `-geminiSelfTest` (runs a real photo check and idea generation and prints the results to the Xcode console), and `-completeDemo` (posts the Patagonia hike so the overflow plays on the current tab).

Notes:
- The category enum is `ChallengeCategory` so it doesn't clash with the Objective-C runtime's `Category`.
- State is saved as JSON in the app's Documents directory (`buckit-demo-state-v4.json`), with photos under `Documents/photos/`. It survives relaunches. **Reset demo** clears both.
- Item and feed photos come from `BuckIt/Data/SeedPictures/` (referenced by filename in `SeedData.swift`). On the Simulator, **Use demo photo** posts `rattlesnake.jpg`.
- Sponsor badges use SF Symbols and brand colors. Each `Sponsor` has a `logoAsset` slot: add an image with that name to the asset catalog, only with the brand's permission, and the badge will use it. Every coupon carries a **DEMO** tag.
