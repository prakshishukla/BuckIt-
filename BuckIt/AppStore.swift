import SwiftUI
import Observation

enum AppTab: Hashable { case home, challenges, profile }

/// Navigation value for opening a group's list.
struct GroupRoute: Hashable { let id: UUID }

/// Everything that persists across launches.
struct DemoState: Codable {
    var hasSignedIn = false
    var hasOnboarded = false
    var contactsSynced = false
    var user: User
    var friends: [User]
    var invitedIDs: Set<UUID> = []
    var groups: [BuckGroup]
    var posts: [Post] = []
    var seedFeedEnabled = true

    static var seed: DemoState {
        DemoState(user: SeedData.me, friends: SeedData.friends, groups: SeedData.seedGroups,
                  posts: SeedData.makeDemoPosts())
    }
}

/// Single source of truth. Mutations go through `update` so every change is saved to disk.
@Observable @MainActor
final class AppStore {
    private(set) var state: DemoState

    // Transient UI state (not persisted)
    var selectedTab: AppTab = .home
    var challengesPath = NavigationPath()
    var activeCapture: Challenge?
    /// The completion count the Profile bucket has animated up to.
    var bucketShownCount: Int
    var bucketLevel: Double
    var splashCount = 0
    private var isAnimatingBucket = false

    let verifier: any VerificationService = VerificationServiceFactory.make()

    init() {
        let loaded = Self.load() ?? .seed
        state = loaded
        bucketShownCount = loaded.user.completedCount
        bucketLevel = Self.level(for: loaded.user.completedCount)

        #if DEBUG
        // Dev shortcut for screenshots: `-skipOnboarding` and `-tab home|challenges|profile` launch arguments.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-skipOnboarding") {
            state.hasSignedIn = true
            state.hasOnboarded = true
        }
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
            selectedTab = ["challenges": .challenges, "profile": .profile][args[i + 1]] ?? .home
        }
        if let i = args.firstIndex(of: "-openGroup"), i + 1 < args.count, i + 1 < args.count,
           let group = state.groups.first(where: { $0.name.lowercased().hasPrefix(args[i + 1].lowercased()) }) {
            selectedTab = .challenges
            challengesPath.append(GroupRoute(id: group.id))
        }
        #endif
    }

    // MARK: - Persistence

    private static var stateURL: URL { URL.documentsDirectory.appending(path: "buckit-demo-state-v2.json") }

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
    var myGroups: [BuckGroup] { state.groups.filter { $0.memberIDs.contains(me.id) } }
    var crewGroup: BuckGroup? { state.groups.first { $0.id == SeedData.crewGroupID } }

    func user(_ id: UUID) -> User? {
        id == me.id ? me : state.friends.first { $0.id == id }
    }

    func group(_ id: UUID) -> BuckGroup? { state.groups.first { $0.id == id } }

    /// Posts from groups I'm in, newest first.
    func feedPosts(groupID: UUID? = nil) -> [Post] {
        let ids = Set(myGroups.map(\.id))
        return state.posts
            .filter { ids.contains($0.groupID) && (groupID == nil || $0.groupID == groupID) }
            .sorted { $0.date > $1.date }
    }

    func myPost(for challengeID: String) -> Post? {
        state.posts.first { $0.userID == me.id && $0.challengeID == challengeID }
    }

    func coupon(for challengeID: String) -> Coupon? {
        me.wallet.first { $0.challengeID == challengeID }
    }

    func isAdded(_ friendID: UUID) -> Bool {
        crewGroup?.memberIDs.contains(friendID) ?? false
    }

    func members(of group: BuckGroup) -> [User] {
        group.memberIDs.compactMap { user($0) }
    }

    /// Group members who have done a challenge (me included), for the avatars on each task.
    func completers(of challengeID: String, in group: BuckGroup) -> [User] {
        members(of: group).filter { member in
            if member.id == me.id { return myPost(for: challengeID) != nil }
            return (SeedData.friendCompletions[challengeID] ?? []).contains(member.id)
                || state.posts.contains { $0.userID == member.id && $0.challengeID == challengeID }
        }
    }

    /// Friends I can tag: my group-mates, or everyone on BuckIt if I haven't added anyone yet.
    var taggableFriends: [User] {
        let ids = Set(myGroups.flatMap(\.memberIDs)).subtracting([me.id])
        let mates = state.friends.filter { ids.contains($0.id) }
        return mates.isEmpty ? onBuckItFriends : mates
    }

    // MARK: - Onboarding

    func signIn() {
        update { $0.hasSignedIn = true }
    }

    /// Any code works: it joins Seattle Summer Crew.
    func joinWithInvite(_ code: String) {
        update { s in
            s.hasSignedIn = true
            if let i = s.groups.firstIndex(where: { $0.id == SeedData.crewGroupID }),
               !s.groups[i].memberIDs.contains(s.user.id) {
                s.groups[i].memberIDs.append(s.user.id)
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
        toggleMember(friendID, in: SeedData.crewGroupID)
    }

    func toggleMember(_ friendID: UUID, in groupID: UUID) {
        update { s in
            guard let i = s.groups.firstIndex(where: { $0.id == groupID }) else { return }
            if let j = s.groups[i].memberIDs.firstIndex(of: friendID) {
                s.groups[i].memberIDs.remove(at: j)
            } else {
                s.groups[i].memberIDs.append(friendID)
            }
        }
    }

    func markInvited(_ friendID: UUID) {
        update { $0.invitedIDs.insert(friendID) }
    }

    func finishOnboarding(groupName: String) {
        let name = groupName.trimmingCharacters(in: .whitespaces)
        update { s in
            if let i = s.groups.firstIndex(where: { $0.id == SeedData.crewGroupID }), !name.isEmpty {
                s.groups[i].name = name
            }
            s.hasOnboarded = true
        }
        selectedTab = .home
    }

    // MARK: - Completing challenges

    /// Saves the photos, adds the post to the feed, bumps the bucket and (if verified + sponsored) mints a coupon.
    @discardableResult
    func completeChallenge(_ challenge: Challenge, photo: UIImage, selfie: UIImage?, locationName: String,
                           date: Date, taggedUserIDs: [UUID], caption: String, verified: Bool) -> (post: Post, coupon: Coupon?) {
        let photoName = PhotoStore.save(photo) ?? PhotoStore.assetPrefix + "demo-hike"
        let selfieName = selfie.flatMap { PhotoStore.save($0) }
        let groupID = myGroups.first { $0.challengeIDs.contains(challenge.id) }?.id
            ?? myGroups.first?.id ?? SeedData.crewGroupID
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)

        let post = Post(id: UUID(), userID: me.id, groupID: groupID, challengeID: challenge.id,
                        photoFilename: photoName, selfieFilename: selfieName, locationName: locationName,
                        date: date, taggedUserIDs: taggedUserIDs, verified: verified, reactions: [:], comments: [],
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

    func setRedeemed(_ couponID: UUID, _ redeemed: Bool) {
        update { s in
            guard let i = s.user.wallet.firstIndex(where: { $0.id == couponID }) else { return }
            s.user.wallet[i].redeemed = redeemed
        }
    }

    // MARK: - Groups

    func createGroup(name: String, emoji: String, memberIDs: [UUID], starter: StarterList) {
        let group = BuckGroup(id: UUID(), name: name, emoji: emoji, memberIDs: [me.id] + memberIDs,
                              challengeIDs: starter.challengeIDs,
                              listName: starter == .blank ? "\(name) list" : starter.title)
        update { s in
            s.groups.append(group)
            s.user.groupIDs.append(group.id)
        }
    }

    // MARK: - Bucket

    static func level(for count: Int) -> Double {
        Double(count % SeedData.dropsPerBucket) / Double(SeedData.dropsPerBucket)
    }

    var bucketNumber: Int { bucketShownCount / SeedData.dropsPerBucket + 1 }

    var bucketDrops: Int {
        bucketLevel >= 0.999 ? SeedData.dropsPerBucket : bucketShownCount % SeedData.dropsPerBucket
    }

    /// Called when Profile appears: raises the water to match new completions, overflowing at 100%.
    func animateBucketIfNeeded() async {
        let target = state.user.completedCount
        guard target != bucketShownCount, !isAnimatingBucket else { return }
        isAnimatingBucket = true
        defer { isAnimatingBucket = false }

        try? await Task.sleep(for: .seconds(0.4))
        let overflows = target > 0 && target % SeedData.dropsPerBucket == 0
        withAnimation(.spring(duration: 1.0, bounce: 0.35)) {
            bucketShownCount = target
            bucketLevel = overflows ? 1.0 : Self.level(for: target)
        }
        splashCount += 1

        if overflows {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeInOut(duration: 0.9)) { bucketLevel = 0 }
        }
    }

    // MARK: - Settings

    func setSeedFeed(_ on: Bool) {
        update { s in
            s.seedFeedEnabled = on
            s.posts.removeAll { SeedData.demoPostIDs.contains($0.id) }
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
        activeCapture = nil
        bucketShownCount = 0
        bucketLevel = 0
    }
}
