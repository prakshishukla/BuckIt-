import Foundation

/// Every hardcoded user, list, challenge and reward in the demo.
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

    static let summerListID = UUID(uuidString: "B0C1E700-0000-4000-8000-0000000000A1")!
    static let trailsListID = UUID(uuidString: "B0C1E700-0000-4000-8000-0000000000A2")!
    static let waterListID = UUID(uuidString: "B0C1E700-0000-4000-8000-0000000000A3")!
    static let eventsListID = UUID(uuidString: "B0C1E700-0000-4000-8000-0000000000A4")!
    static let springListID = UUID(uuidString: "B0C1E700-0000-4000-8000-0000000000A5")!
    static let summerListName = "Seattle Summer 2026"

    static let fallbackLocation = "Discovery Park, Seattle"
    static let inviteURL = URL(string: "https://buckit.app/join/SEATTLE26")!
    static let inviteMessage = "Join my BuckIt list! https://buckit.app/join/SEATTLE26"
    static let dropsPerBucket = 10
    /// Bundled photo used by "Use demo photo" on the Simulator.
    static let demoPhotoName = "rattlesnake.jpg"

    // MARK: - People

    static var me: User {
        User(id: meID, firstName: "Buck", lastName: "It", city: "Seattle", season: .summer, commitment: .medium,
             listIDs: [summerListID, trailsListID, waterListID, eventsListID, springListID], wallet: [], completedCount: 0, isOnBuckIt: true)
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
             listIDs: [], wallet: [], completedCount: onBuckIt ? 3 : 0, isOnBuckIt: onBuckIt, phone: phone)
    }

    // MARK: - Lists

    static var seedLists: [BuckList] {
        [
            // Friends join this one during onboarding ("Add").
            BuckList(id: summerListID, name: summerListName, emoji: "🌊", memberIDs: [meID],
                     challengeIDs: StarterList.seattleSummer.challengeIDs),
            BuckList(id: trailsListID, name: "PNW Trails", emoji: "🥾", memberIDs: [meID, jordanID, priyaID],
                     challengeIDs: [patagoniaHikeID, "spon-walgreens-firstaid", "spon-albertsons-snacks", "spon-amazon-gear",
                                    "sea-rattlesnake", "sea-rainier", "sea-burke-gilman", "sea-green-lake"]),
            BuckList(id: waterListID, name: "Islands & Water", emoji: "⛴️", memberIDs: [meID, dylanID, mayaID],
                     challengeIDs: ["spon-costco-bbq", "sea-lake-union", "sea-bainbridge", "sea-alki", "sea-san-juans", "sea-seafair"]),
            BuckList(id: eventsListID, name: "Eat, Drink & Events", emoji: "🎟️", memberIDs: [meID, mayaID, priyaID, jordanID],
                     challengeIDs: ["spon-kroger-dinner", "spon-target-fit", "sea-pike-place", "sea-ballard-market", "sea-patio",
                                    "sea-brewery", "sea-mariners", "sea-concert", "sea-outdoor-movie", "sea-seattle-center"]),
            // Already finished by Buck (see makeMyPastPosts) so the Completed lists section has something in it.
            BuckList(id: springListID, name: "Spring Weekend", emoji: "🌸", memberIDs: [meID, mayaID, priyaID],
                     challengeIDs: ["sea-patio", "sea-ballard-market", "sea-seattle-center"]),
        ]
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
                  category: .outdoors, location: "Any trail around Seattle", commitment: .medium, sponsor: patagonia,
                  criteria: ["Photo on a trail or at a summit",
                             "Shows the outdoors: trees, mountains, or trail",
                             "Location + timestamp attached"],
                  reward: reward("15% off one item", "Valid on one item at Patagonia.", "PATA"),
                  symbol: "figure.hiking"),
        Challenge(id: arcteryxCampID, title: "Camp out + post it",
                  description: "Spend a night under the stars — tent, hammock, or car camping all count — and share it on Instagram tagging @arcteryx.",
                  category: .bigTrips, location: "Anywhere under the stars", commitment: .high, sponsor: arcteryx,
                  criteria: ["Photo of your campsite or tent",
                             "Screenshot or confirmation of the Instagram post"],
                  reward: reward("5% off a hat", "Valid on one hat at Arc'teryx.", "ARCX")),
        Challenge(id: "spon-visa-adventure", title: "Adventure on your card",
                  description: "Start your adventure the right way — use your Visa credit card for gear, a ferry ticket, or trail snacks.",
                  category: .smallTrips, location: nil, commitment: .low, sponsor: visa,
                  criteria: ["Photo of the receipt or purchase moment",
                             "Card number hidden"],
                  reward: reward("+15,000 bonus points", "Credited to your linked Visa card (mock Visa-linked flow).", "VISA")),
        Challenge(id: "spon-walmart-picnic", title: "Picnic provisioner",
                  description: "Stock up on picnic supplies and host a group picnic at any park.",
                  category: .withFriends, location: "Any park", commitment: .medium, sponsor: walmart,
                  criteria: ["Photo of the picnic spread", "At least 2 friends in the shot"],
                  reward: reward("$5 off a $40 grocery order", "Valid on one grocery order of $40+ at Walmart.", "WMT")),
        Challenge(id: "spon-amazon-gear", title: "Gear up for the trail",
                  description: "Grab one new piece of outdoor gear and take it on its first adventure.",
                  category: .outdoors, location: nil, commitment: .medium, sponsor: amazon,
                  criteria: ["Photo of the gear in use", "Taken outdoors"],
                  reward: reward("10% off one outdoor item", "Valid on one outdoor item on Amazon.", "AMZN")),
        Challenge(id: "spon-costco-bbq", title: "Bulk BBQ at the beach",
                  description: "Throw a beach BBQ big enough for the whole crew.",
                  category: .withFriends, location: "Any beach", commitment: .medium, sponsor: costco,
                  criteria: ["Grill in the shot", "Group at a beach"],
                  reward: reward("$10 off a $75 purchase", "Valid on one purchase of $75+ at Costco.", "COST"),
                  symbol: "flame.fill"),
        Challenge(id: "spon-kroger-dinner", title: "Farmers-to-table dinner",
                  description: "Cook a meal with local produce and eat it outside. (QFC and Fred Meyer count in Seattle.)",
                  category: .food, location: nil, commitment: .medium, sponsor: kroger,
                  criteria: ["Meal made with local produce", "Eaten outdoors"],
                  reward: reward("$5 off fresh produce", "Valid at QFC, Fred Meyer, or any Kroger store.", "KRGR")),
        Challenge(id: "spon-homedepot-campfire", title: "Backyard campfire night",
                  description: "Set up a fire pit or string lights and host a backyard night.",
                  category: .withFriends, location: "Your backyard", commitment: .medium, sponsor: homeDepot,
                  criteria: ["Fire pit or string lights setup", "Taken at night"],
                  reward: reward("10% off an outdoor living item", "Valid on one outdoor living item at Home Depot.", "HDPT")),
        Challenge(id: "spon-cvs-sunsafe", title: "Sun-safe summer",
                  description: "Pack sunscreen for a full day out and reapply like a pro.",
                  category: .outdoors, location: nil, commitment: .high, sponsor: cvs,
                  criteria: ["You, outdoors", "SPF visible in the shot"],
                  reward: reward("$3 off sun care", "Valid on any sun care item at CVS.", "CVS")),
        Challenge(id: "spon-target-fit", title: "Summer fit check",
                  description: "Put together a summer adventure outfit and wear it on a challenge.",
                  category: .entertainment, location: nil, commitment: .low, sponsor: target,
                  criteria: ["Your summer adventure outfit", "At an outdoor spot"],
                  reward: reward("15% off one summer apparel item", "Valid on one summer apparel item at Target.", "TGT")),
        Challenge(id: "spon-walgreens-firstaid", title: "First-aid ready",
                  description: "Assemble a mini first-aid kit for the crew before a hike.",
                  category: .outdoors, location: "Any trailhead", commitment: .low, sponsor: walgreens,
                  criteria: ["Mini first-aid kit visible", "At the trailhead"],
                  reward: reward("$5 off first-aid supplies", "Valid on first-aid supplies at Walgreens.", "WAG")),
        Challenge(id: "spon-albertsons-snacks", title: "Trail snack stash",
                  description: "Build the ultimate trail-mix bar for your group hike. (Safeway counts in Seattle.)",
                  category: .food, location: nil, commitment: .low, sponsor: albertsons,
                  criteria: ["Trail snacks visible", "On the trail"],
                  reward: reward("$4 off snacks", "Valid on snacks at Safeway or any Albertsons store.", "SFWY")),
        Challenge(id: "spon-lowes-plant", title: "Plant something",
                  description: "Plant a tree, garden bed, or window box this summer.",
                  category: .outdoors, location: nil, commitment: .medium, sponsor: lowes,
                  criteria: ["You with the planting", "Tree, garden bed, or window box"],
                  reward: reward("10% off garden supplies", "Valid on garden supplies at Lowe's.", "LOWE")),
    ]

    // MARK: - Seattle bucket list (each matches a photo in Data/SeedPictures)

    static let sectionOrder = ["Sponsored picks", "On the Water", "Trails & Parks", "Eat & Drink", "Events & Culture", "Your additions"]
    private static let water = "On the Water"
    private static let trails = "Trails & Parks"
    private static let food = "Eat & Drink"
    private static let culture = "Events & Culture"

    static let seattleChallenges: [Challenge] = [
        Challenge(id: "sea-lake-union", title: "Kayak or paddleboard on Lake Union",
                  description: "Rent a kayak or SUP and paddle past the houseboats, seaplanes and the Seattle skyline.",
                  category: .outdoors, location: "Lake Union", commitment: .medium, section: water,
                  symbol: "sailboat.fill", imageName: "lakeunion.jpg"),
        Challenge(id: "sea-bainbridge", title: "Washington State Ferry to Bainbridge Island",
                  description: "Catch the ferry from Colman Dock, watch the skyline shrink, and explore Winslow on foot.",
                  category: .smallTrips, location: "Colman Dock → Bainbridge Island", commitment: .medium, section: water,
                  symbol: "ferry.fill", imageName: "bainbridge.jpg"),
        Challenge(id: "sea-alki", title: "Alki Beach",
                  description: "Beach walk, volleyball, or fish and chips with a view of the city from West Seattle.",
                  category: .outdoors, location: "Alki Beach, West Seattle", commitment: .low, section: water,
                  symbol: "beach.umbrella.fill", imageName: "alki.jpg"),
        Challenge(id: "sea-san-juans", title: "San Juan Islands",
                  description: "Ferry out to the San Juans, explore Friday Harbor, and try to spot an orca.",
                  category: .bigTrips, location: "San Juan Islands", commitment: .high, section: water,
                  symbol: "ferry.fill", imageName: "sanjuan.jpg"),
        Challenge(id: "sea-green-lake", title: "Green Lake",
                  description: "Walk, run, or bike the 2.8-mile loop around Green Lake, then grab a treat nearby.",
                  category: .outdoors, location: "Green Lake Park", commitment: .low, section: trails,
                  symbol: "figure.run", imageName: "greenlake.jpg"),
        Challenge(id: "sea-rattlesnake", title: "Rattlesnake Ledge or Mount Si",
                  description: "Hike up to the ledge (4 mi) or tackle Mount Si (8 mi) for big views over the Snoqualmie Valley.",
                  category: .outdoors, location: "North Bend", commitment: .high, section: trails,
                  symbol: "figure.hiking", imageName: "rattlesnake.jpg"),
        Challenge(id: "sea-rainier", title: "Mount Rainier day trip",
                  description: "Drive to Paradise or Sunrise, hike among the wildflowers, and picnic with the mountain.",
                  category: .bigTrips, location: "Mount Rainier National Park", commitment: .high, section: trails,
                  symbol: "mountain.2.fill", imageName: "rainier.jpg"),
        Challenge(id: "sea-gas-works", title: "Gas Works Park",
                  description: "Fly a kite on the hill, picnic by the old towers, and watch the sunset over Lake Union.",
                  category: .withFriends, location: "Gas Works Park, Wallingford", commitment: .low, section: trails,
                  symbol: "wind", imageName: "gasworks.jpg"),
        Challenge(id: "sea-burke-gilman", title: "Burke-Gilman Trail",
                  description: "Bike or walk a stretch of the 20-mile trail from Ballard through Fremont and UW.",
                  category: .outdoors, location: "Burke-Gilman Trail", commitment: .medium, section: trails,
                  symbol: "bicycle", imageName: "burkegilman.jpg"),
        Challenge(id: "sea-pike-place", title: "Pike Place Market",
                  description: "Watch the fish fly, grab a pastry, and wander the lower levels for hidden shops.",
                  category: .food, location: "Pike Place Market", commitment: .low, section: food,
                  symbol: "basket.fill", imageName: "pikeplace.jpg"),
        Challenge(id: "sea-ballard-market", title: "Ballard Farmers Market",
                  description: "Sunday on Ballard Ave: local produce, flowers, and way too many samples.",
                  category: .localEvents, location: "Ballard Ave NW", commitment: .low, section: food,
                  symbol: "carrot.fill", imageName: "ballardmarket.jpg"),
        Challenge(id: "sea-patio", title: "Outdoor patio dining",
                  description: "Find the best sunny patio in the city and make a long lunch of it.",
                  category: .food, location: "Anywhere sunny", commitment: .low, section: food,
                  symbol: "fork.knife", imageName: "patio.jpg"),
        Challenge(id: "sea-brewery", title: "Brewery or distillery tour",
                  description: "Tour a Ballard brewery or a local distillery and try a flight (21+).",
                  category: .withFriends, location: "Ballard Brewery District", commitment: .medium, section: food,
                  symbol: "mug.fill", imageName: "brewery.jpg"),
        Challenge(id: "sea-mariners", title: "Mariners game at T-Mobile Park",
                  description: "Garlic fries, a seventh-inning stretch, and maybe a home run.",
                  category: .entertainment, location: "T-Mobile Park, SoDo", commitment: .medium, section: culture,
                  symbol: "baseball.fill", imageName: "tmobile.jpg"),
        Challenge(id: "sea-concert", title: "Outdoor concert",
                  description: "Catch live music outside: Zoo Tunes, a park show, or a summer festival.",
                  category: .entertainment, location: "Around Seattle", commitment: .medium, section: culture,
                  symbol: "music.note", imageName: "concert.jpg"),
        Challenge(id: "sea-seafair", title: "Seafair events",
                  description: "Hydroplane races, the Blue Angels, or a Seafair parade. Peak Seattle summer.",
                  category: .localEvents, location: "Lake Washington", commitment: .high, section: culture,
                  symbol: "airplane", imageName: "seafair.jpg"),
        Challenge(id: "sea-outdoor-movie", title: "Free outdoor movie",
                  description: "Bring a blanket and snacks to a free summer movie in the park.",
                  category: .entertainment, location: "Seattle parks", commitment: .low, section: culture,
                  symbol: "film.fill", imageName: "outdoormovie.jpg"),
        Challenge(id: "sea-seattle-center", title: "Seattle Center (Space Needle, Chihuly, MoPOP)",
                  description: "Go up the Space Needle, wander Chihuly Garden and Glass, or get lost in MoPOP.",
                  category: .culture, location: "Seattle Center", commitment: .medium, section: culture,
                  symbol: "building.2.fill", imageName: "seattlecenter.jpg"),
    ]

    static let allChallenges = sponsoredChallenges + seattleChallenges
    private static let challengesByID = Dictionary(uniqueKeysWithValues: allChallenges.map { ($0.id, $0) })
    static func challenge(_ id: String) -> Challenge? { challengesByID[id] }

    /// Which friends have done each challenge (avatars on tasks, friend profiles).
    static let friendCompletions: [String: [UUID]] = [
        patagoniaHikeID: [priyaID, jordanID, dylanID],
        arcteryxCampID: [jordanID],
        "spon-walgreens-firstaid": [priyaID],
        "spon-albertsons-snacks": [jordanID, priyaID],
        "spon-costco-bbq": [dylanID, mayaID],
        "spon-kroger-dinner": [mayaID],
        "sea-gas-works": [mayaID, priyaID, dylanID],
        "sea-alki": [dylanID, mayaID],
        "sea-mariners": [jordanID, mayaID, priyaID],
        "sea-pike-place": [mayaID, priyaID],
        "sea-bainbridge": [dylanID, mayaID],
        "sea-green-lake": [priyaID, mayaID],
        "sea-lake-union": [mayaID, dylanID, jordanID],
        "sea-concert": [jordanID, priyaID],
        "sea-rattlesnake": [jordanID, priyaID],
        "sea-brewery": [dylanID, jordanID],
        "sea-seattle-center": [mayaID],
        "sea-outdoor-movie": [priyaID],
        "sea-ballard-market": [mayaID],
        "sea-burke-gilman": [priyaID, jordanID],
    ]

    // MARK: - Demo feed (on by default; toggle in Settings)

    static let demoPostIDs: [UUID] = (1...9).map { UUID(uuidString: String(format: "B0C1E700-0000-4000-8000-0000000000%02X", 0xD0 + $0))! }

    static func makeDemoPosts() -> [Post] {
        let ids = demoPostIDs
        let now = Date()
        func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }
        func c(_ user: UUID, _ text: String, _ hours: Double) -> Comment {
            Comment(id: UUID(), userID: user, text: text, date: ago(hours))
        }
        func post(_ i: Int, _ user: UUID, _ list: UUID, _ challenge: String, _ photo: String, _ place: String, _ hours: Double,
                  tagged: [UUID], reactions: [String: [UUID]], comments: [Comment], caption: String, reward: String? = nil) -> Post {
            Post(id: ids[i], userID: user, listID: list, challengeID: challenge, photoFilename: PhotoStore.assetPrefix + photo,
                 selfieFilename: nil, locationName: place, date: ago(hours), taggedUserIDs: tagged, reactions: reactions,
                 comments: comments, caption: caption, sharedRewardHeadline: reward)
        }
        return [
            post(0, mayaID, summerListID, "sea-gas-works", "gasworks.jpg", "Gas Works Park, Seattle", 1.5,
                 tagged: [priyaID], reactions: ["🔥": [dylanID, priyaID], "🌊": [jordanID]],
                 comments: [c(dylanID, "kite hill is undefeated", 1.2), c(priyaID, "best sunset this summer", 1.0)],
                 caption: "Picnic + sunset at the towers"),
            post(1, priyaID, trailsListID, patagoniaHikeID, "rainier.jpg", "Skyline Trail, Mt. Rainier", 4,
                 tagged: [jordanID], reactions: ["🔥": [jordanID, mayaID, dylanID], "🙌": [jordanID]],
                 comments: [c(jordanID, "sandwich summit 🥪", 3.5),
                            c(mayaID, "wait you got 15% off at Patagonia for this?? signing up", 3)],
                 caption: "5.5 miles and the best lunch view in the state", reward: "15% off one item"),
            post(2, dylanID, waterListID, "sea-alki", "alki.jpg", "Alki Beach, West Seattle", 7,
                 tagged: [mayaID], reactions: ["🙌": [mayaID], "😂": [jordanID], "🌊": [priyaID]],
                 comments: [c(mayaID, "save me some fish and chips next time", 6)],
                 caption: "Fish & chips + sunset = perfect"),
            post(3, jordanID, eventsListID, "sea-mariners", "tmobile.jpg", "T-Mobile Park, SoDo", 20,
                 tagged: [mayaID, priyaID], reactions: ["🔥": [mayaID, priyaID], "😂": [dylanID]],
                 comments: [c(priyaID, "the garlic fries were the real MVP", 19), c(mayaID, "go M's!!", 18.5)],
                 caption: "Walk-off energy ⚾️"),
            post(4, mayaID, eventsListID, "sea-pike-place", "pikeplace.jpg", "Pike Place Market", 28,
                 tagged: [], reactions: ["🙌": [priyaID, jordanID]],
                 comments: [c(jordanID, "did you catch a fish", 27)],
                 caption: "Flowers, pastries, and one very loud fish toss"),
            post(5, dylanID, waterListID, "sea-bainbridge", "bainbridge.jpg", "Bainbridge Island Ferry", 34,
                 tagged: [mayaID], reactions: ["🌊": [mayaID, priyaID], "🔥": [jordanID]],
                 comments: [c(mayaID, "ferry > traffic", 33)],
                 caption: "Skyline from the top deck"),
            post(6, priyaID, trailsListID, "sea-green-lake", "greenlake.jpg", "Green Lake, Seattle", 45,
                 tagged: [], reactions: ["🔥": [mayaID, dylanID, jordanID]],
                 comments: [c(mayaID, "loop #2 next weekend?", 44)],
                 caption: "2.8 miles done before coffee ☕️"),
            post(7, mayaID, waterListID, "sea-lake-union", "lakeunion.jpg", "Lake Union, Seattle", 60,
                 tagged: [dylanID], reactions: ["🌊": [dylanID, priyaID], "😂": [jordanID]],
                 comments: [c(dylanID, "we only fell in once", 59), c(priyaID, "iconic", 58)],
                 caption: "Paddled past the Sleepless in Seattle houseboat"),
            post(8, jordanID, eventsListID, "sea-concert", "concert.jpg", "Marymoor Park", 80,
                 tagged: [priyaID], reactions: ["🙌": [priyaID, mayaID]],
                 comments: [c(priyaID, "still hoarse", 79)],
                 caption: "Lawn seats were the move"),
        ]
    }
}

extension SeedData {
    /// Buck's earlier completions: 9 drops of mixed activity types, so the bucket starts colorful at 9/10
    /// and the demo's Patagonia post overflows it.
    static let myPastPostIDs: [UUID] = (1...9).map { UUID(uuidString: String(format: "B0C1E700-0000-4000-8000-0000000000%02X", 0xE0 + $0))! }

    static func makeMyPastPosts() -> [Post] {
        let now = Date()
        let items: [(String, UUID, String, String, Double, String)] = [
            ("sea-san-juans", waterListID, "sanjuan.jpg", "Friday Harbor, San Juan Island", 60, "No orcas but the ferry ride was unreal"),
            ("sea-burke-gilman", trailsListID, "burkegilman.jpg", "Burke-Gilman Trail", 52, "Fremont to UW and back"),
            ("sea-seafair", waterListID, "seafair.jpg", "Lake Washington", 45, "Blue Angels flyover!!"),
            ("sea-patio", springListID, "patio.jpg", "Capitol Hill", 38, "Three-hour lunch, zero regrets"),
            ("sea-ballard-market", springListID, "ballardmarket.jpg", "Ballard Ave NW", 37, "Came for peaches, left with flowers"),
            ("sea-seattle-center", springListID, "seattlecenter.jpg", "Seattle Center", 36, "Chihuly glass is even better in person"),
            ("sea-brewery", eventsListID, "brewery.jpg", "Ballard Brewery District", 25, "Flight of four, favorite was the hazy"),
            ("sea-outdoor-movie", eventsListID, "outdoormovie.jpg", "Magnuson Park", 18, "Blankets + popcorn under the stars"),
            ("sea-green-lake", trailsListID, "greenlake.jpg", "Green Lake, Seattle", 12, "Sunset loop"),
        ]
        return items.enumerated().map { i, item in
            Post(id: myPastPostIDs[i], userID: meID, listID: item.1, challengeID: item.0,
                 photoFilename: PhotoStore.assetPrefix + item.2, selfieFilename: nil, locationName: item.3,
                 date: now.addingTimeInterval(-item.4 * 86400), taggedUserIDs: [], reactions: ["🔥": [mayaID]],
                 comments: [], caption: item.5)
        }
    }
}

/// Lists a new list can start from.
enum StarterList: String, CaseIterable, Identifiable {
    case seattleSummer, sponsoredSummer, blank

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seattleSummer: "Seattle summer classics"
        case .sponsoredSummer: "Sponsored challenges"
        case .blank: "Start from scratch"
        }
    }

    var subtitle: String {
        switch self {
        case .seattleSummer: "\(SeedData.seattleChallenges.count) Seattle favorites + 2 sponsored"
        case .sponsoredSummer: "Every sponsored challenge"
        case .blank: "Add items yourself"
        }
    }

    var challengeIDs: [String] {
        switch self {
        case .seattleSummer:
            [SeedData.patagoniaHikeID, SeedData.arcteryxCampID] + SeedData.seattleChallenges.map(\.id)
        case .sponsoredSummer:
            SeedData.sponsoredChallenges.map(\.id)
        case .blank:
            []
        }
    }
}
