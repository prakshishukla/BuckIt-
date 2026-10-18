import SwiftUI
import Observation

enum AppTab: Hashable { case home, challenges, profile, sponsor }

/// Navigation value for opening a list.
struct ListRoute: Hashable { let id: UUID }

/// Navigation value for opening a friend's profile.
struct FriendRoute: Hashable { let id: UUID }

/// What the capture flow was opened for: a specific item, or nil from the Home camera (pick the item after shooting).
struct CaptureRequest: Identifiable {
    let id = UUID()
    var challenge: Challenge?
    var listID: UUID?
}

/// Everything that persists across launches.
struct DemoState: Codable {
    var hasSignedIn = false
    var hasOnboarded = false
    var contactsSynced = false
    var user: User
    var friends: [User]
    var invitedIDs: Set<UUID> = []
    var lists: [BuckList]
    /// Items people added themselves from a list's "+" sheet.
    var customChallenges: [Challenge] = []
    var posts: [Post] = []
    var seedFeedEnabled = true
    /// Custom bucket water colors per activity type (hex). Missing = the type's default.
    var waterColorHex: [String: String] = [:]

    static var seed: DemoState {
        let mine = SeedData.makeMyPastPosts()
        var user = SeedData.me
        user.completedCount = mine.count
        return DemoState(user: user, friends: SeedData.friends, lists: SeedData.seedLists,
                         posts: SeedData.makeDemoPosts() + mine)
    }
}

/// Single source of truth. Mutations go through `update` so every change is saved to disk.
@Observable @MainActor
final class AppStore {
    private(set) var state: DemoState

    // Transient UI state (not persisted)
    var selectedTab: AppTab = .home
    var challengesPath = NavigationPath()
    var profilePath = NavigationPath()
    var activeCapture: CaptureRequest?
    /// The completion count the Profile bucket has animated up to.
    var bucketShownCount: Int
    var bucketLevel: Double
    var splashCount = 0
    /// Set while the full-screen overflow celebration plays: the colors that were in the bucket.
    var overflowColors: [Color]?
    private var isAnimatingBucket = false

    let verifier: any VerificationService = VerificationServiceFactory.make()

    init() {
        let loaded = Self.load() ?? .seed
        state = loaded
        bucketShownCount = loaded.user.completedCount
        bucketLevel = Self.level(for: loaded.user.completedCount)

        #if DEBUG
        // Dev shortcuts for screenshots: `-skipOnboarding`, `-tab home|challenges|profile`, `-openList <name prefix>`.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-skipOnboarding") {
            state.hasSignedIn = true
            state.hasOnboarded = true
        }
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
            selectedTab = ["challenges": .challenges, "profile": .profile, "sponsor": .sponsor][args[i + 1]] ?? .home
        }
        if let i = args.firstIndex(of: "-openList"), i + 1 < args.count,
           let list = state.lists.first(where: { $0.name.lowercased().hasPrefix(args[i + 1].lowercased()) }) {
            selectedTab = .challenges
            challengesPath.append(ListRoute(id: list.id))
        }
        if let i = args.firstIndex(of: "-openProfileList"), i + 1 < args.count,
           let list = state.lists.first(where: { $0.name.lowercased().hasPrefix(args[i + 1].lowercased()) }) {
            selectedTab = .profile
            profilePath.append(ListRoute(id: list.id))
        }
        if args.contains("-completeDemo"), let hike = SeedData.challenge(SeedData.patagoniaHikeID),
           let photo = UIImage(named: SeedData.demoPhotoName) {
            // Posts the Patagonia hike (the 10th drop): the overflow plays right away on whatever tab is showing.
            completeChallenge(hike, listID: SeedData.trailsListID, photo: photo, selfie: nil, locationName: SeedData.fallbackLocation,
                              date: .now, taggedUserIDs: [], caption: "", verified: true)
        }
        if let i = args.firstIndex(of: "-openFriend"), i + 1 < args.count,
           let friend = state.friends.first(where: { $0.firstName.lowercased() == args[i + 1].lowercased() }) {
            selectedTab = .profile
            profilePath.append(FriendRoute(id: friend.id))
        }
        #endif
    }

    // MARK: - Persistence

    private static var stateURL: URL { URL.documentsDirectory.appending(path: "buckit-demo-state-v4.json") }

    private static func load() -> DemoState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DemoState.self, from: data)
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            try encoder.encode(state).write(to: Self.stateURL, options: .atomic)
        } catch {
            print("BuckIt: failed to save state: \(error)")
        }
    }

    private func update(_ change: (inout DemoState) -> Void) {
        change(&state)
        persist()
    }

    // MARK: - Lookups

    var me: User { state.user }
    var onBuckItFriends: [User] { state.friends.filter(\.isOnBuckIt) }
    var inviteFriends: [User] { state.friends.filter { !$0.isOnBuckIt } }
    var myLists: [BuckList] { state.lists.filter { $0.memberIDs.contains(me.id) } }
    /// I've done every item on it.
    func isCompleted(_ list: BuckList) -> Bool {
        !list.challengeIDs.isEmpty && list.challengeIDs.allSatisfy { myPost(for: $0) != nil }
    }

    var activeLists: [BuckList] { myLists.filter { !isCompleted($0) } }
    var completedLists: [BuckList] { myLists.filter { isCompleted($0) } }

    /// How many items on a list someone has done.
    func progress(of userID: UUID, in list: BuckList) -> Int {
        list.challengeIDs.filter { hasDone(userID, $0) }.count
    }

    /// The list friends are added to during onboarding.
    var summerList: BuckList? { state.lists.first { $0.id == SeedData.summerListID } }

    func user(_ id: UUID) -> User? {
        id == me.id ? me : state.friends.first { $0.id == id }
    }

    func list(_ id: UUID) -> BuckList? { state.lists.first { $0.id == id } }

    /// Seeded catalog plus the user's own items.
    func challenge(_ id: String) -> Challenge? {
        state.customChallenges.first { $0.id == id } ?? SeedData.challenge(id)
    }

    func challenges(in list: BuckList) -> [Challenge] {
        list.challengeIDs.compactMap { challenge($0) }
    }

    /// Posts from lists I'm on, newest first.
    func feedPosts(listID: UUID? = nil) -> [Post] {
        let ids = Set(myLists.map(\.id))
        return state.posts
            .filter { ids.contains($0.listID) && (listID == nil || $0.listID == listID) }
            .sorted { $0.date > $1.date }
    }

    func myPost(for challengeID: String) -> Post? {
        state.posts.first { $0.userID == me.id && $0.challengeID == challengeID }
    }

    func coupon(for challengeID: String) -> Coupon? {
        me.wallet.first { $0.challengeID == challengeID }
    }

    func isAdded(_ friendID: UUID) -> Bool {
        summerList?.memberIDs.contains(friendID) ?? false
    }

    func members(of list: BuckList) -> [User] {
        list.memberIDs.compactMap { user($0) }
    }

    func hasDone(_ userID: UUID, _ challengeID: String) -> Bool {
        if userID == me.id { return myPost(for: challengeID) != nil }
        return (SeedData.friendCompletions[challengeID] ?? []).contains(userID)
            || state.posts.contains { $0.userID == userID && $0.challengeID == challengeID }
    }

    /// List members who have done an item (me included), for the avatars on each task.
    func completers(of challengeID: String, in list: BuckList) -> [User] {
        members(of: list).filter { hasDone($0.id, challengeID) }
    }

    /// Lists both I and this friend are on.
    func mutualLists(with friendID: UUID) -> [BuckList] {
        myLists.filter { $0.memberIDs.contains(friendID) }
    }

    /// The most recent post by someone for an item, if any (used for friend-profile thumbnails).
    func latestPost(by userID: UUID, for challengeID: String) -> Post? {
        state.posts.filter { $0.userID == userID && $0.challengeID == challengeID }.max { $0.date < $1.date }
    }

    /// My lists that don't contain this item yet (for "Add to list").
    func listsMissing(_ challengeID: String) -> [BuckList] {
        myLists.filter { !$0.challengeIDs.contains(challengeID) }
    }

    /// Friends I can tag: people on my lists, or everyone on BuckIt if I haven't added anyone yet.
    var taggableFriends: [User] {
        let ids = Set(myLists.flatMap(\.memberIDs)).subtracting([me.id])
        let mates = state.friends.filter { ids.contains($0.id) }
        return mates.isEmpty ? onBuckItFriends : mates
    }

    // MARK: - Onboarding

    func signIn() {
        update { $0.hasSignedIn = true }
    }

    /// Any code works: it joins the Seattle Summer list.
    func joinWithInvite(_ code: String) {
        update { s in
            s.hasSignedIn = true
            if let i = s.lists.firstIndex(where: { $0.id == SeedData.summerListID }),
               !s.lists[i].memberIDs.contains(s.user.id) {
                s.lists[i].memberIDs.append(s.user.id)
            }
        }
    }

    func savePreferences(firstName: String, lastName: String, city: String, season: Season, commitment: Commitment? = nil) {
        update { s in
            s.user.firstName = firstName.trimmingCharacters(in: .whitespaces).isEmpty ? "Buck" : firstName
            s.user.lastName = lastName.trimmingCharacters(in: .whitespaces).isEmpty ? "It" : lastName
            s.user.city = city
            s.user.season = season
            if let commitment { s.user.commitment = commitment }
        }
    }

    func syncContacts() {
        update { $0.contactsSynced = true }
    }

    func toggleAdded(_ friendID: UUID) {
        toggleMember(friendID, in: SeedData.summerListID)
    }

    func toggleMember(_ friendID: UUID, in listID: UUID) {
        update { s in
            guard let i = s.lists.firstIndex(where: { $0.id == listID }) else { return }
            if let j = s.lists[i].memberIDs.firstIndex(of: friendID) {
                s.lists[i].memberIDs.remove(at: j)
            } else {
                s.lists[i].memberIDs.append(friendID)
            }
        }
    }

    func markInvited(_ friendID: UUID) {
        update { $0.invitedIDs.insert(friendID) }
    }

    func finishOnboarding(listName: String) {
        let name = listName.trimmingCharacters(in: .whitespaces)
        update { s in
            if let i = s.lists.firstIndex(where: { $0.id == SeedData.summerListID }), !name.isEmpty {
                s.lists[i].name = name
            }
            s.hasOnboarded = true
        }
        selectedTab = .home
    }

    // MARK: - Lists

    func createList(name: String, emoji: String, memberIDs: [UUID], starter: StarterList) {
        let list = BuckList(id: UUID(), name: name, emoji: emoji, memberIDs: [me.id] + memberIDs,
                            challengeIDs: starter.challengeIDs)
        update { s in
            s.lists.append(list)
            s.user.listIDs.append(list.id)
        }
    }

    func addItem(_ challengeID: String, to listID: UUID) {
        update { s in
            guard let i = s.lists.firstIndex(where: { $0.id == listID }),
                  !s.lists[i].challengeIDs.contains(challengeID) else { return }
            s.lists[i].challengeIDs.append(challengeID)
        }
    }

    /// Creates a new item of the user's own and adds it to a list.
    func addCustomItem(title: String, description: String, location: String, commitment: Commitment,
                       category: ChallengeCategory, to listID: UUID) {
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let item = Challenge(id: "custom-" + UUID().uuidString, title: title.trimmingCharacters(in: .whitespaces),
                             description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                             category: category, location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                             commitment: commitment, section: "Your additions", isCustom: true)
        update { s in
            s.customChallenges.append(item)
            if let i = s.lists.firstIndex(where: { $0.id == listID }) {
                s.lists[i].challengeIDs.append(item.id)
            }
        }
    }

    // MARK: - Completing challenges

    func startCapture(_ challenge: Challenge? = nil, listID: UUID? = nil) {
        activeCapture = CaptureRequest(challenge: challenge, listID: listID)
    }

    /// Saves the photos, adds the post to the feed, bumps the bucket and (for verified sponsored items) mints a coupon.
    @discardableResult
    func completeChallenge(_ challenge: Challenge, listID: UUID?, photo: UIImage, selfie: UIImage?, locationName: String,
                           date: Date, taggedUserIDs: [UUID], caption: String, verified: Bool) -> (post: Post, coupon: Coupon?) {
        let photoName = PhotoStore.save(photo) ?? PhotoStore.assetPrefix + SeedData.demoPhotoName
        let selfieName = selfie.flatMap { PhotoStore.save($0) }
        let resolvedListID = listID
            ?? myLists.first { $0.challengeIDs.contains(challenge.id) }?.id
            ?? myLists.first?.id ?? SeedData.summerListID
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)

        let post = Post(id: UUID(), userID: me.id, listID: resolvedListID, challengeID: challenge.id,
                        photoFilename: photoName, selfieFilename: selfieName, locationName: locationName,
                        date: date, taggedUserIDs: taggedUserIDs, reactions: [:], comments: [],
                        caption: trimmedCaption.isEmpty ? nil : trimmedCaption)

        var coupon: Coupon?
        if verified, let reward = challenge.reward, let sponsor = challenge.sponsor {
            coupon = Coupon(id: UUID(), challengeID: challenge.id, sponsorName: sponsor.name,
                            sponsorColorHex: sponsor.colorHex, sponsorSymbol: sponsor.symbol,
                            headline: reward.headline, detail: reward.detail,
                            code: Self.makeCode(prefix: reward.codePrefix),
                            expiresAt: Calendar.current.date(byAdding: .day, value: reward.expiresInDays, to: .now) ?? .now,
                            redeemed: false)
        }

        update { s in
            s.posts.insert(post, at: 0)
            s.user.completedCount += 1
            if let coupon { s.user.wallet.insert(coupon, at: 0) }
            // Posting an item that isn't on the list yet adds it.
            if let i = s.lists.firstIndex(where: { $0.id == resolvedListID }), !s.lists[i].challengeIDs.contains(challenge.id) {
                s.lists[i].challengeIDs.append(challenge.id)
            }
        }
        // The moment the bucket fills, play the overflow wherever the user is.
        let count = state.user.completedCount
        if count % SeedData.dropsPerBucket == 0 {
            Task { await playOverflow(at: count) }
        }
        return (post, coupon)
    }

    static func makeCode(prefix: String) -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return prefix + "-" + String((0..<6).map { _ in chars.randomElement()! })
    }

    /// Closes the capture flow and lands on Home with the new post on top.
    func finishCapture() {
        selectedTab = .home
        activeCapture = nil
        challengesPath = NavigationPath()
    }

    // MARK: - Feed

    func shareReward(postID: UUID, headline: String) {
        update { s in
            guard let i = s.posts.firstIndex(where: { $0.id == postID }) else { return }
            s.posts[i].sharedRewardHeadline = headline
        }
    }

    func toggleReaction(_ emoji: String, postID: UUID) {
        let myID = me.id
        update { s in
            guard let i = s.posts.firstIndex(where: { $0.id == postID }) else { return }
            var users = s.posts[i].reactions[emoji] ?? []
            if let j = users.firstIndex(of: myID) { users.remove(at: j) } else { users.append(myID) }
            s.posts[i].reactions[emoji] = users.isEmpty ? nil : users
        }
    }

    func addComment(_ text: String, postID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let comment = Comment(id: UUID(), userID: me.id, text: trimmed, date: .now)
        update { s in
            guard let i = s.posts.firstIndex(where: { $0.id == postID }) else { return }
            s.posts[i].comments.append(comment)
        }
    }

    // MARK: - Wallet

    /// Marks a coupon used and records what was bought; optionally shares it on the original post.
    func recordPurchase(_ couponID: UUID, note: String, shareToFeed: Bool) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        update { s in
            guard let i = s.user.wallet.firstIndex(where: { $0.id == couponID }) else { return }
            s.user.wallet[i].redeemed = true
            s.user.wallet[i].purchaseNote = trimmed.isEmpty ? nil : trimmed
            let challengeID = s.user.wallet[i].challengeID
            if shareToFeed, !trimmed.isEmpty,
               let j = s.posts.firstIndex(where: { $0.userID == s.user.id && $0.challengeID == challengeID }) {
                s.posts[j].sharedPurchase = trimmed
            }
        }
    }

    func setRedeemed(_ couponID: UUID, _ redeemed: Bool) {
        update { s in
            guard let i = s.user.wallet.firstIndex(where: { $0.id == couponID }) else { return }
            s.user.wallet[i].redeemed = redeemed
        }
    }

    // MARK: - Bucket

    func waterColor(_ category: ChallengeCategory) -> Color {
        Color(hex: state.waterColorHex[category.rawValue] ?? category.defaultHex)
    }

    func setWaterColor(_ color: Color, for category: ChallengeCategory) {
        update { $0.waterColorHex[category.rawValue] = color.hexString }
    }

    func resetWaterColors() {
        update { $0.waterColorHex = [:] }
    }

    /// My completions, oldest first; each one is a drop in the bucket.
    private var myDrops: [ChallengeCategory] {
        state.posts.filter { $0.userID == me.id }
            .sorted { $0.date < $1.date }
            .map { challenge($0.challengeID)?.category ?? .outdoors }
    }

    /// Colored layers for the bucket currently shown (bottom first).
    var bucketLayers: [Color] {
        layers(forCount: bucketShownCount, full: bucketLevel >= 0.999)
    }

    /// Layers after `count` completions; `full` keeps all 10 of a just-filled bucket instead of starting a new one.
    func layers(forCount count: Int, full: Bool) -> [Color] {
        let drops = Array(myDrops.prefix(count))
        let inBucket = full ? SeedData.dropsPerBucket : count % SeedData.dropsPerBucket
        return drops.suffix(inBucket).map { waterColor($0) }
    }

    /// Activity types in the current bucket, for the legend.
    var bucketCategories: [ChallengeCategory] {
        let drops = Array(myDrops.prefix(bucketShownCount))
        let inBucket = bucketLevel >= 0.999 ? SeedData.dropsPerBucket : bucketShownCount % SeedData.dropsPerBucket
        var seen: [ChallengeCategory] = []
        for c in drops.suffix(inBucket) where !seen.contains(c) { seen.append(c) }
        return seen
    }

    static func level(for count: Int) -> Double {
        Double(count % SeedData.dropsPerBucket) / Double(SeedData.dropsPerBucket)
    }

    var bucketNumber: Int { bucketShownCount / SeedData.dropsPerBucket + 1 }

    var bucketDrops: Int {
        bucketLevel >= 0.999 ? SeedData.dropsPerBucket : bucketShownCount % SeedData.dropsPerBucket
    }

    /// Called when Profile appears: raises the water to match new completions.
    /// (A full bucket is handled by `playOverflow` the moment it fills.)
    func animateBucketIfNeeded() async {
        let target = state.user.completedCount
        guard target != bucketShownCount, !isAnimatingBucket, overflowColors == nil else { return }
        isAnimatingBucket = true
        defer { isAnimatingBucket = false }

        try? await Task.sleep(for: .seconds(0.4))
        withAnimation(.spring(duration: 1.0, bounce: 0.35)) {
            bucketShownCount = target
            bucketLevel = Self.level(for: target)
        }
        splashCount += 1
    }

    /// Full bucket: water in the bucket's colors floods the screen (shown over any page, including the capture
    /// flow), then a fresh empty bucket is waiting on Profile.
    func playOverflow(at count: Int) async {
        var seen: [ChallengeCategory] = []
        for c in myDrops.prefix(count).suffix(SeedData.dropsPerBucket) where !seen.contains(c) { seen.append(c) }
        let colors = seen.map { waterColor($0) }

        bucketShownCount = count
        bucketLevel = 1
        try? await Task.sleep(for: .seconds(0.6))
        withAnimation(.easeIn(duration: 0.2)) { overflowColors = colors.isEmpty ? [Theme.primary] : colors }
        try? await Task.sleep(for: .seconds(3.6))
        bucketLevel = 0 // hidden behind the water
        try? await Task.sleep(for: .seconds(1.4))
        withAnimation(.easeOut(duration: 0.6)) { overflowColors = nil }
    }

    // MARK: - Sponsor View

    /// Campaign funnel including this demo user's own activity, so the dashboard moves during the demo.
    func liveFunnel(_ campaign: SponsorCampaign) -> (added: Int, waiting: Int, redeemed: Int) {
        let onMyList = myLists.contains { $0.challengeIDs.contains(campaign.challengeID) }
        let coupon = coupon(for: campaign.challengeID)
        return (campaign.addedToList + (onMyList ? 1 : 0),
                campaign.waitingForCoupon + (coupon != nil && coupon?.redeemed == false ? 1 : 0),
                campaign.redeemed + (coupon?.redeemed == true ? 1 : 0))
    }

    /// Recent "what I bought" shares, newest first (mine on top when I've shared one).
    func purchases(_ campaign: SponsorCampaign) -> [(name: String, item: String, daysAgo: Int)] {
        var list = campaign.purchases
        if let note = coupon(for: campaign.challengeID)?.purchaseNote {
            list.insert(("\(me.firstName) \(me.lastName.prefix(1)).", note, 0), at: 0)
        }
        return list
    }

    /// Share of someone's completed items that are a given activity type.
    func activityShare(of userID: UUID, _ category: ChallengeCategory) -> (share: Double, total: Int) {
        let ids = Set(SeedData.allChallenges.map(\.id).filter { hasDone(userID, $0) })
            .union(state.posts.filter { $0.userID == userID }.map(\.challengeID))
        let done = ids.compactMap { challenge($0) }
        guard !done.isEmpty else { return (0, 0) }
        return (Double(done.filter { $0.category == category }.count) / Double(done.count), done.count)
    }

    // MARK: - Settings

    func setSeedFeed(_ on: Bool) {
        let demoIDs = Set(SeedData.demoPostIDs)
        update { s in
            s.seedFeedEnabled = on
            s.posts.removeAll { demoIDs.contains($0.id) }
            if on { s.posts.append(contentsOf: SeedData.makeDemoPosts()) }
        }
    }

    /// Restores the seed state, back to the sign-in screen.
    func resetDemo() {
        PhotoStore.deleteAll()
        state = .seed
        persist()
        selectedTab = .home
        challengesPath = NavigationPath()
        profilePath = NavigationPath()
        activeCapture = nil
        bucketShownCount = state.user.completedCount
        bucketLevel = Self.level(for: state.user.completedCount)
        overflowColors = nil
    }
}
