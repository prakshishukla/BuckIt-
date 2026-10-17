import Foundation

/// Every hardcoded user, group, challenge and reward in the demo.
enum SeedData {

    // MARK: - IDs & constants

    static let meID = UUID(uuidString: "B0C1E700-0000-4000-8000-000000000001")!
    static let dylanID = UUID(uuidString: "B0C1E700-0000-4000-8000-000000000002")!
    static let mayaID = UUID(uuidString: "B0C1E700-0000-4000-8000-000000000003")!
    static let jordanID = UUID(uuidString: "B0C1E700-0000-4000-8000-000000000004")!
    static let priyaID = UUID(uuidString: "B0C1E700-0000-4000-8000-000000000005")!
    static let samID = UUID(uuidString: "B0C1E700-0000-4000-8000-000000000006")!
    static let alexID = UUID(uuidString: "B0C1E700-0000-4000-8000-000000000007")!
    static let taylorID = UUID(uuidString: "B0C1E700-0000-4000-8000-000000000008")!
    static let chrisID = UUID(uuidString: "B0C1E700-0000-4000-8000-000000000009")!

    static let crewGroupID = UUID(uuidString: "B0C1E700-0000-4000-8000-0000000000A1")!
    static let crewGroupName = "Seattle Summer Crew 🌊"
    static let seattleListName = "Seattle Bucket List 2026"

    static let fallbackLocation = "Discovery Park, Seattle"
    static let inviteURL = URL(string: "https://buckit.app/join/SEATTLE26")!
    static let inviteMessage = "Join my BuckIt group! https://buckit.app/join/SEATTLE26"
    static let dropsPerBucket = 10

    // MARK: - People

    static var me: User {
        User(id: meID, firstName: "Buck", lastName: "It", city: "Seattle", season: .summer, commitment: .medium,
             groupIDs: [crewGroupID], wallet: [], completedCount: 0, isOnBuckIt: true)
    }

    static let friends: [User] = [
        friend(dylanID, "Dylan", "Park", onBuckIt: true, phone: "(206) 555-0142"),
        friend(mayaID, "Maya", "Chen", onBuckIt: true, phone: "(206) 555-0178"),
        friend(jordanID, "Jordan", "Lee", onBuckIt: true, phone: "(206) 555-0113"),
        friend(priyaID, "Priya", "Shah", onBuckIt: true, phone: "(206) 555-0190"),
        friend(samID, "Sam", "Rivera", onBuckIt: false, phone: "(206) 555-0124"),
        friend(alexID, "Alex", "Kim", onBuckIt: false, phone: "(425) 555-0156"),
        friend(taylorID, "Taylor", "Nguyen", onBuckIt: false, phone: "(206) 555-0167"),
        friend(chrisID, "Chris", "Ortiz", onBuckIt: false, phone: "(253) 555-0101"),
    ]

    private static func friend(_ id: UUID, _ first: String, _ last: String, onBuckIt: Bool, phone: String) -> User {
        User(id: id, firstName: first, lastName: last, city: "Seattle", season: .summer, commitment: .medium,
             groupIDs: onBuckIt ? [crewGroupID] : [], wallet: [], completedCount: onBuckIt ? 3 : 0,
             isOnBuckIt: onBuckIt, phone: phone)
    }

    static var crewGroup: BuckGroup {
        BuckGroup(id: crewGroupID, name: crewGroupName, emoji: "🌊", memberIDs: [meID],
                  challengeIDs: StarterList.seattle2026.challengeIDs, listName: seattleListName)
    }

    // MARK: - Sponsors

    static let patagonia = Sponsor(name: "Patagonia", colorHex: "#E2582B", symbol: "mountain.2.fill")
    static let arcteryx = Sponsor(name: "Arc'teryx", colorHex: "#2E2E2E", symbol: "tent.fill")
    static let visa = Sponsor(name: "Visa", colorHex: "#1A1F71", symbol: "creditcard.fill")
    static let walmart = Sponsor(name: "Walmart", colorHex: "#0071CE", symbol: "basket.fill")
    static let amazon = Sponsor(name: "Amazon", colorHex: "#E08700", symbol: "shippingbox.fill")
    static let costco = Sponsor(name: "Costco Wholesale", colorHex: "#E31837", symbol: "cart.fill")
    static let kroger = Sponsor(name: "The Kroger Co.", colorHex: "#134B97", symbol: "carrot.fill")
    static let homeDepot = Sponsor(name: "Home Depot", colorHex: "#F96302", symbol: "hammer.fill")
    static let cvs = Sponsor(name: "CVS Health", colorHex: "#CC0000", symbol: "sun.max.fill")
    static let target = Sponsor(name: "Target", colorHex: "#CC0000", symbol: "tshirt.fill")
    static let walgreens = Sponsor(name: "Walgreens Boots Alliance", colorHex: "#E31837", symbol: "cross.case.fill")
    static let albertsons = Sponsor(name: "Albertsons Companies", colorHex: "#00529F", symbol: "takeoutbag.and.cup.and.straw.fill")
    static let lowes = Sponsor(name: "Lowe's", colorHex: "#004990", symbol: "leaf.fill")

    private static func reward(_ headline: String, _ detail: String, _ prefix: String) -> RewardTemplate {
        RewardTemplate(headline: headline, detail: detail, codePrefix: prefix, expiresInDays: 30)
    }

    // MARK: - Sponsored challenges

    static let patagoniaHikeID = "spon-patagonia-hike"
    static let arcteryxCampID = "spon-arcteryx-camp"

    static let sponsoredChallenges: [Challenge] = [
        Challenge(id: patagoniaHikeID, title: "Hike 5+ miles",
                  description: "Lace up and log at least 5 miles on any trail around Seattle. Bonus points for a summit view.",
                  category: .hike, location: "Any trail around Seattle", commitment: .medium, sponsor: patagonia,
                  criteria: ["Photo on a trail or at a summit",
                             "Shows the outdoors: trees, mountains, or trail",
                             "Location + timestamp attached"],
                  reward: reward("15% off one item", "Valid on one item at Patagonia.", "PATA"),
                  symbol: "figure.hiking"),
        Challenge(id: arcteryxCampID, title: "Camp out + post it",
                  description: "Spend a night under the stars — tent, hammock, or car camping all count — and share it on Instagram tagging @arcteryx.",
                  category: .park, location: "Anywhere under the stars", commitment: .high, sponsor: arcteryx,
                  criteria: ["Photo of your campsite or tent",
                             "Screenshot or confirmation of the Instagram post"],
                  reward: reward("5% off a hat", "Valid on one hat at Arc'teryx.", "ARCX")),
        Challenge(id: "spon-visa-adventure", title: "Adventure on your card",
                  description: "Start your adventure the right way — use your Visa credit card for gear, a ferry ticket, or trail snacks.",
                  category: .finance, location: nil, commitment: .low, sponsor: visa,
                  criteria: ["Photo of the receipt or purchase moment",
                             "Card number hidden"],
                  reward: reward("+15,000 bonus points", "Credited to your linked Visa card (mock Visa-linked flow).", "VISA")),
        Challenge(id: "spon-walmart-picnic", title: "Picnic provisioner",
                  description: "Stock up on picnic supplies and host a group picnic at any park.",
                  category: .park, location: "Any park", commitment: .medium, sponsor: walmart,
                  criteria: ["Photo of the picnic spread", "At least 2 friends in the shot"],
                  reward: reward("$5 off a $40 grocery order", "Valid on one grocery order of $40+ at Walmart.", "WMT")),
        Challenge(id: "spon-amazon-gear", title: "Gear up for the trail",
                  description: "Grab one new piece of outdoor gear and take it on its first adventure.",
                  category: .shopping, location: nil, commitment: .medium, sponsor: amazon,
                  criteria: ["Photo of the gear in use", "Taken outdoors"],
                  reward: reward("10% off one outdoor item", "Valid on one outdoor item on Amazon.", "AMZN")),
        Challenge(id: "spon-costco-bbq", title: "Bulk BBQ at the beach",
                  description: "Throw a beach BBQ big enough for the whole crew.",
                  category: .water, location: "Any beach", commitment: .medium, sponsor: costco,
                  criteria: ["Grill in the shot", "Group at a beach"],
                  reward: reward("$10 off a $75 purchase", "Valid on one purchase of $75+ at Costco.", "COST"),
                  symbol: "flame.fill"),
        Challenge(id: "spon-kroger-dinner", title: "Farmers-to-table dinner",
                  description: "Cook a meal with local produce and eat it outside. (QFC and Fred Meyer count in Seattle.)",
                  category: .market, location: nil, commitment: .medium, sponsor: kroger,
                  criteria: ["Meal made with local produce", "Eaten outdoors"],
                  reward: reward("$5 off fresh produce", "Valid at QFC, Fred Meyer, or any Kroger store.", "KRGR")),
        Challenge(id: "spon-homedepot-campfire", title: "Backyard campfire night",
                  description: "Set up a fire pit or string lights and host a backyard night.",
                  category: .shopping, location: "Your backyard", commitment: .medium, sponsor: homeDepot,
                  criteria: ["Fire pit or string lights setup", "Taken at night"],
                  reward: reward("10% off an outdoor living item", "Valid on one outdoor living item at Home Depot.", "HDPT")),
        Challenge(id: "spon-cvs-sunsafe", title: "Sun-safe summer",
                  description: "Pack sunscreen for a full day out and reapply like a pro.",
                  category: .park, location: nil, commitment: .high, sponsor: cvs,
                  criteria: ["You, outdoors", "SPF visible in the shot"],
                  reward: reward("$3 off sun care", "Valid on any sun care item at CVS.", "CVS")),
        Challenge(id: "spon-target-fit", title: "Summer fit check",
                  description: "Put together a summer adventure outfit and wear it on a challenge.",
                  category: .shopping, location: nil, commitment: .low, sponsor: target,
                  criteria: ["Your summer adventure outfit", "At an outdoor spot"],
                  reward: reward("15% off one summer apparel item", "Valid on one summer apparel item at Target.", "TGT")),
        Challenge(id: "spon-walgreens-firstaid", title: "First-aid ready",
                  description: "Assemble a mini first-aid kit for the crew before a hike.",
                  category: .hike, location: "Any trailhead", commitment: .low, sponsor: walgreens,
                  criteria: ["Mini first-aid kit visible", "At the trailhead"],
                  reward: reward("$5 off first-aid supplies", "Valid on first-aid supplies at Walgreens.", "WAG")),
        Challenge(id: "spon-albertsons-snacks", title: "Trail snack stash",
                  description: "Build the ultimate trail-mix bar for your group hike. (Safeway counts in Seattle.)",
                  category: .hike, location: nil, commitment: .low, sponsor: albertsons,
                  criteria: ["Trail snacks visible", "On the trail"],
                  reward: reward("$4 off snacks", "Valid on snacks at Safeway or any Albertsons store.", "SFWY")),
        Challenge(id: "spon-lowes-plant", title: "Plant something",
                  description: "Plant a tree, garden bed, or window box this summer.",
                  category: .park, location: nil, commitment: .medium, sponsor: lowes,
                  criteria: ["You with the planting", "Tree, garden bed, or window box"],
                  reward: reward("10% off garden supplies", "Valid on garden supplies at Lowe's.", "LOWE")),
    ]

    // MARK: - Seattle Bucket List 2026

    private static let local = "Local"
    private static let parks = "Parks & Adventures"

    static let seattleChallenges: [Challenge] = [
        Challenge(id: "sea-golden-gardens", title: "Golden Gardens sunset",
                  description: "Catch a sunset (and maybe a bonfire) on the sandy beach at Golden Gardens in Ballard.",
                  category: .water, location: "Golden Gardens Park, Ballard", commitment: .low, section: local, symbol: "sun.horizon.fill"),
        Challenge(id: "sea-mercer-island", title: "Explore Mercer Island",
                  description: "Bike or walk the Mercer Island loop and find a swim spot at Luther Burbank Park.",
                  category: .island, location: "Mercer Island", commitment: .medium, section: local, symbol: "bicycle"),
        Challenge(id: "sea-arboretum", title: "Washington Park Arboretum",
                  description: "Wander the trails and Japanese Garden in the Arboretum.",
                  category: .park, location: "Washington Park Arboretum", commitment: .low, section: local, symbol: "leaf.fill"),
        Challenge(id: "sea-swim-cut", title: "Swim in the Cut",
                  description: "Brave the Montlake Cut — jump in where the locals do (safely, with a buddy).",
                  category: .water, location: "Montlake Cut", commitment: .low, section: local),
        Challenge(id: "sea-kayak", title: "Kayak from Agua Verde",
                  description: "Rent a kayak at Agua Verde and paddle Portage Bay, then grab tacos.",
                  category: .water, location: "Agua Verde Paddle Club, Portage Bay", commitment: .medium, section: local, symbol: "sailboat.fill"),
        Challenge(id: "sea-water-taxi", title: "Ride the Water Taxi",
                  description: "Take the West Seattle Water Taxi from downtown to Alki for skyline views.",
                  category: .ride, location: "Pier 50 → Seacrest Dock", commitment: .low, section: local, symbol: "ferry.fill"),
        Challenge(id: "sea-bike-bainbridge", title: "Bike Bainbridge",
                  description: "Ferry to Bainbridge Island with your bike and ride the island.",
                  category: .island, location: "Bainbridge Island", commitment: .high, section: local, symbol: "bicycle"),
        Challenge(id: "sea-dylans-park", title: "Dylan's Bellevue park",
                  description: "The Bellevue park Dylan swears by — go find out why.",
                  category: .park, location: "Bellevue Downtown Park", commitment: .low, section: local),
        Challenge(id: "sea-lake-washington", title: "Swim in Lake Washington",
                  description: "Take a summer dip at Madison Park or Matthews Beach.",
                  category: .water, location: "Madison Park or Matthews Beach", commitment: .low, section: local),
        Challenge(id: "sea-green-lake", title: "Loop Green Lake",
                  description: "Walk, run, or paddleboard the 2.8-mile loop around Green Lake.",
                  category: .park, location: "Green Lake Park", commitment: .low, section: local, symbol: "figure.run"),
        Challenge(id: "sea-fremont-market", title: "Fremont Sunday Market",
                  description: "Hunt for treasures and eat your way through the Fremont Sunday Market.",
                  category: .market, location: "Fremont Sunday Market", commitment: .low, section: local),

        Challenge(id: "sea-kite-hill", title: "Fly a kite at Kite Hill",
                  description: "Get a kite airborne at Gas Works Park's Kite Hill.",
                  category: .park, location: "Gas Works Park", commitment: .low, section: parks, symbol: "wind"),
        Challenge(id: "sea-kerry-park", title: "Kerry Park view",
                  description: "Snap the classic Space Needle + Mt. Rainier skyline shot at Kerry Park.",
                  category: .park, location: "Kerry Park, Queen Anne", commitment: .low, section: parks, symbol: "building.2.fill"),
        Challenge(id: "sea-discovery-lighthouse", title: "Discovery Park lighthouse",
                  description: "Hike the loop trail down to West Point Lighthouse.",
                  category: .hike, location: "Discovery Park", commitment: .medium, section: parks, symbol: "light.beacon.max.fill"),
        Challenge(id: "sea-alki", title: "Alki Beach day",
                  description: "Beach walk, volleyball, or fish and chips at Alki.",
                  category: .water, location: "Alki Beach, West Seattle", commitment: .low, section: parks, symbol: "beach.umbrella.fill"),
        Challenge(id: "sea-san-juans", title: "San Juan Islands trip",
                  description: "Ferry out to the San Juans and try to spot an orca.",
                  category: .island, location: "San Juan Islands", commitment: .high, section: parks),
        Challenge(id: "sea-rainier", title: "Mt. Rainier",
                  description: "Visit Paradise or Sunrise and hike among the wildflowers.",
                  category: .hike, location: "Mount Rainier National Park", commitment: .high, section: parks, symbol: "mountain.2.fill"),
        Challenge(id: "sea-three-fingers", title: "Three Fingers hike",
                  description: "Tackle the challenging Three Fingers trail for the lookout views.",
                  category: .hike, location: "Three Fingers Lookout", commitment: .high, section: parks),
    ]

    static let allChallenges = sponsoredChallenges + seattleChallenges
    private static let challengesByID = Dictionary(uniqueKeysWithValues: allChallenges.map { ($0.id, $0) })
    static func challenge(_ id: String) -> Challenge? { challengesByID[id] }

    /// Which friends "have done" each challenge, for avatars on the detail screen.
    static let friendCompletions: [String: [UUID]] = [
        patagoniaHikeID: [dylanID, mayaID],
        arcteryxCampID: [jordanID],
        "sea-golden-gardens": [mayaID, priyaID, dylanID],
        "sea-kerry-park": [mayaID],
        "sea-alki": [dylanID],
        "sea-green-lake": [priyaID],
        "sea-kayak": [jordanID],
        "sea-discovery-lighthouse": [dylanID, priyaID],
        "sea-fremont-market": [mayaID, jordanID],
    ]

    // MARK: - Demo feed (toggled from Settings)

    static let demoPostIDs: Set<UUID> = [
        UUID(uuidString: "B0C1E700-0000-4000-8000-0000000000D1")!,
        UUID(uuidString: "B0C1E700-0000-4000-8000-0000000000D2")!,
        UUID(uuidString: "B0C1E700-0000-4000-8000-0000000000D3")!,
        UUID(uuidString: "B0C1E700-0000-4000-8000-0000000000D4")!,
    ]

    static func makeDemoPosts(groupID: UUID) -> [Post] {
        let ids = demoPostIDs.sorted { $0.uuidString < $1.uuidString }
        let now = Date()
        func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }
        func comment(_ user: UUID, _ text: String, _ hours: Double) -> Comment {
            Comment(id: UUID(), userID: user, text: text, date: ago(hours))
        }
        return [
            Post(id: ids[0], userID: mayaID, groupID: groupID, challengeID: "sea-kerry-park",
                 photoFilename: PhotoStore.assetPrefix + "feed-kerry", selfieFilename: nil,
                 locationName: "Kerry Park, Seattle", date: ago(2), taggedUserIDs: [priyaID], verified: false,
                 reactions: ["🔥": [dylanID, priyaID], "🌊": [jordanID]],
                 comments: [comment(dylanID, "The mountain was OUT 😍", 1.5)],
                 caption: "Rainier said hi"),
            Post(id: ids[1], userID: dylanID, groupID: groupID, challengeID: "sea-alki",
                 photoFilename: PhotoStore.assetPrefix + "feed-alki", selfieFilename: nil,
                 locationName: "Alki Beach, West Seattle", date: ago(5), taggedUserIDs: [], verified: false,
                 reactions: ["🙌": [mayaID], "😂": [jordanID]],
                 comments: [comment(mayaID, "save me some fish and chips next time", 4)],
                 caption: "Fish & chips + sunset = perfect"),
            Post(id: ids[2], userID: priyaID, groupID: groupID, challengeID: "sea-green-lake",
                 photoFilename: PhotoStore.assetPrefix + "feed-greenlake", selfieFilename: nil,
                 locationName: "Green Lake, Seattle", date: ago(26), taggedUserIDs: [mayaID], verified: false,
                 reactions: ["🔥": [mayaID, dylanID, jordanID]], comments: [],
                 caption: "2.8 miles done before coffee ☕️"),
            Post(id: ids[3], userID: jordanID, groupID: groupID, challengeID: "sea-kayak",
                 photoFilename: PhotoStore.assetPrefix + "feed-kayak", selfieFilename: nil,
                 locationName: "Portage Bay, Seattle", date: ago(50), taggedUserIDs: [dylanID], verified: false,
                 reactions: ["🌊": [priyaID, mayaID]],
                 comments: [comment(priyaID, "tacos after?? 🌮", 49)],
                 caption: "Tacos earned"),
        ]
    }
}

/// Lists a new group can start from.
enum StarterList: String, CaseIterable, Identifiable {
    case seattle2026, sponsoredSummer, blank

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seattle2026: SeedData.seattleListName
        case .sponsoredSummer: "Sponsored Summer"
        case .blank: "Start from scratch"
        }
    }

    var subtitle: String {
        switch self {
        case .seattle2026: "\(SeedData.seattleChallenges.count) Seattle classics + 2 sponsored"
        case .sponsoredSummer: "Every sponsored challenge"
        case .blank: "Add challenges later"
        }
    }

    var challengeIDs: [String] {
        switch self {
        case .seattle2026:
            [SeedData.patagoniaHikeID, SeedData.arcteryxCampID] + SeedData.seattleChallenges.map(\.id)
        case .sponsoredSummer:
            SeedData.sponsoredChallenges.map(\.id)
        case .blank:
            []
        }
    }
}
