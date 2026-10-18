import SwiftUI

/// Demo-only dashboard for brands: who the campaign targets, how many people it reached,
/// and the funnel from "added to a list" to "redeemed and used", plus Gemini campaign ideas.
struct SponsorView: View {
    @Environment(AppStore.self) private var store
    @State private var selected = SeedData.campaigns[0].id
    @State private var previewThreshold: Double = SeedData.campaigns[0].threshold

    private var campaign: SponsorCampaign {
        SeedData.campaigns.first { $0.id == selected } ?? SeedData.campaigns[0]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sponsorPicker
                    CampaignHeader(campaign: campaign)
                    AudienceCard(campaign: campaign, previewThreshold: $previewThreshold)
                    FunnelCard(campaign: campaign)
                    PurchasesCard(campaign: campaign)
                    NeighborhoodsCard(campaign: campaign)
                    CampaignIdeasCard(campaign: campaign)
                    Text("Demo data. Sponsors only see aggregate numbers and what people chose to share.")
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(16)
                .animation(.snappy, value: selected)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Sponsor View")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("DEMO")
                        .font(.app(.caption2, weight: .heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.cream, in: Capsule())
                        .foregroundStyle(Theme.plumFixed)
                }
            }
            .onChange(of: selected) { previewThreshold = campaign.threshold }
        }
    }

    private var sponsorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SeedData.campaigns) { c in
                    Button {
                        selected = c.id
                    } label: {
                        SponsorBadge(sponsor: c.sponsor, style: c.id == selected ? .filled : .onColor)
                            .overlay(Capsule().stroke(Color(hex: c.sponsor.colorHex).opacity(c.id == selected ? 0 : 0.5), lineWidth: 1))
                            .scaleEffect(c.id == selected ? 1.05 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}

// MARK: - Header

private struct CampaignHeader: View {
    let campaign: SponsorCampaign

    var body: some View {
        let challenge = SeedData.challenge(campaign.challengeID)
        let brand = Color(hex: campaign.sponsor.colorHex)
        HStack(spacing: 14) {
            Image(systemName: challenge?.iconSymbol ?? campaign.sponsor.symbol)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("Live campaign").font(.app(.caption, weight: .semibold)).opacity(0.85)
                Text(challenge?.title ?? "Campaign").font(.display(.title2, weight: .heavy))
                Text("Reward: \(challenge?.reward?.headline ?? "—")").font(.app(.subheadline, weight: .medium)).opacity(0.9)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(LinearGradient(colors: [brand, brand.opacity(0.75), Theme.plumFixed], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

// MARK: - Audience

private struct AudienceCard: View {
    @Environment(AppStore.self) private var store
    let campaign: SponsorCampaign
    @Binding var previewThreshold: Double

    var body: some View {
        let share = campaign.share(atThreshold: previewThreshold)
        let people = Int((Double(campaign.cityUsers) * share).rounded())
        let atLive = abs(previewThreshold - campaign.threshold) < 0.001

        VStack(alignment: .leading, spacing: 14) {
            Label("Who you can advertise to", systemImage: "scope")
                .font(.display(.title3))
                .foregroundStyle(Theme.plum)

            // The rule, stated plainly.
            HStack(spacing: 10) {
                Image(systemName: campaign.targetCategory.symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(campaign.targetCategory.tint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("≥ \(Int(previewThreshold * 100))% \(campaign.targetCategory.label)")
                        .font(.display(.title2, weight: .heavy))
                        .contentTransition(.numericText())
                    Text(campaign.audienceNote).font(.app(.caption)).foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .center, spacing: 18) {
                Gauge(share: share, tint: campaign.targetCategory.tint)
                    .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 4) {
                    Text(atLive ? "Marketed to" : "Would reach")
                        .font(.app(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(people.formatted())
                        .font(.display(.largeTitle, weight: .heavy))
                        .contentTransition(.numericText())
                    Text("of \(campaign.cityUsers.formatted()) Seattle users")
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Slider(value: $previewThreshold, in: 0.2...0.9, step: 0.05)
                    .tint(campaign.targetCategory.tint)
                HStack {
                    Text("Broader").font(.app(.caption2))
                    Spacer()
                    if !atLive {
                        Button("Reset to live (\(Int(campaign.threshold * 100))%)") {
                            withAnimation { previewThreshold = campaign.threshold }
                        }
                        .font(.app(.caption, weight: .semibold))
                    }
                    Spacer()
                    Text("More targeted").font(.app(.caption2))
                }
                .foregroundStyle(.secondary)
            }

            Divider()

            Text("People in your audience").font(.app(.subheadline, weight: .semibold))
            ForEach(audienceSample) { row in
                HStack(spacing: 10) {
                    AvatarView(user: row.user, size: 32)
                    Text(row.user.id == store.me.id ? "\(row.user.firstName) (you)" : row.user.firstName)
                        .font(.app(.subheadline, weight: .medium))
                    Spacer()
                    Text("\(Int(row.share * 100))% \(campaign.targetCategory.label.lowercased())")
                        .font(.app(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: row.share >= previewThreshold ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(row.share >= previewThreshold ? Theme.teal : .secondary)
                }
            }
        }
        .card()
        .animation(.snappy, value: previewThreshold)
    }

    private struct AudienceRow: Identifiable {
        var id: UUID { user.id }
        let user: User
        let share: Double
    }

    private var audienceSample: [AudienceRow] {
        ([store.me] + store.onBuckItFriends)
            .map { AudienceRow(user: $0, share: store.activityShare(of: $0.id, campaign.targetCategory).share) }
            .sorted { $0.share > $1.share }
    }
}

private struct Gauge: View {
    let share: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.15), lineWidth: 12)
            Circle()
                .trim(from: 0, to: share)
                .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((share * 100).rounded()))%")
                .font(.display(.title3, weight: .heavy))
                .contentTransition(.numericText())
        }
        .animation(.snappy, value: share)
        .accessibilityElement()
        .accessibilityLabel("\(Int(share * 100)) percent of users")
    }
}

// MARK: - Funnel

private struct FunnelCard: View {
    @Environment(AppStore.self) private var store
    let campaign: SponsorCampaign

    var body: some View {
        let funnel = store.liveFunnel(campaign)
        let base = Double(campaign.marketedTo)
        let steps: [(String, String, Int, Color)] = [
            ("Added the task to their list", "plus.circle.fill", funnel.added, Theme.primary),
            ("Submitted, waiting to use the coupon", "hourglass", funnel.waiting, Theme.lavender),
            ("Redeemed and used the coupon", "bag.fill", funnel.redeemed, Theme.teal),
        ]

        VStack(alignment: .leading, spacing: 14) {
            Label("Campaign funnel", systemImage: "line.3.horizontal.decrease")
                .font(.display(.title3))
                .foregroundStyle(Theme.plum)
            Text("Out of the \(campaign.marketedTo.formatted()) people marketed to")
                .font(.app(.caption))
                .foregroundStyle(.secondary)

            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                let fraction = base > 0 ? Double(step.2) / base : 0
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(step.0, systemImage: step.1).font(.app(.subheadline, weight: .medium))
                        Spacer()
                        Text(step.2.formatted())
                            .font(.app(.headline, weight: .bold))
                            .contentTransition(.numericText())
                        Text(fraction, format: .percent.precision(.fractionLength(0)))
                            .font(.app(.caption, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(step.3.opacity(0.15))
                            Capsule().fill(step.3.gradient).frame(width: max(6, geo.size.width * fraction))
                        }
                    }
                    .frame(height: 10)
                }
            }

            let redeemRate = funnel.added > 0 ? Double(funnel.redeemed) / Double(funnel.added) : 0
            Text("\(redeemRate.formatted(.percent.precision(.fractionLength(0)))) of people who added the task have used the coupon.")
                .font(.app(.caption, weight: .medium))
                .foregroundStyle(Theme.teal)
        }
        .card()
    }
}

// MARK: - Purchases

private struct PurchasesCard: View {
    @Environment(AppStore.self) private var store
    let campaign: SponsorCampaign

    var body: some View {
        let items = store.purchases(campaign)
        VStack(alignment: .leading, spacing: 12) {
            Label("What people bought", systemImage: "bag.fill")
                .font(.display(.title3))
                .foregroundStyle(Theme.plum)
            ForEach(Array(items.prefix(6).enumerated()), id: \.offset) { _, p in
                HStack {
                    Text(p.item).font(.app(.subheadline, weight: .semibold))
                    Spacer()
                    Text("\(p.name) · \(p.daysAgo == 0 ? "today" : "\(p.daysAgo)d ago")")
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            Text("Shared by people from their Wallet after using the coupon.")
                .font(.app(.caption))
                .foregroundStyle(.secondary)
        }
        .card()
    }
}

// MARK: - Neighborhoods

private struct NeighborhoodsCard: View {
    let campaign: SponsorCampaign

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Where your audience is", systemImage: "map.fill")
                .font(.display(.title3))
                .foregroundStyle(Theme.plum)
            ForEach(campaign.neighborhoods, id: \.0) { name, share in
                HStack(spacing: 10) {
                    Text(name).font(.app(.subheadline)).frame(width: 120, alignment: .leading)
                    GeometryReader { geo in
                        Capsule().fill(Color(hex: campaign.sponsor.colorHex).gradient)
                            .frame(width: geo.size.width * share / 0.25)
                    }
                    .frame(height: 10)
                    Text(share, format: .percent.precision(.fractionLength(0)))
                        .font(.app(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .card()
    }
}

// MARK: - Gemini campaign ideas (genAI for sponsors)

private struct CampaignIdea: Identifiable, Decodable {
    var id: String { title }
    var title: String
    var challenge: String
    var audience: String
    var why: String
}

private struct CampaignIdeasCard: View {
    let campaign: SponsorCampaign
    @State private var ideas: [CampaignIdea] = []
    @State private var loading = false
    @State private var fromGemini = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Next campaign ideas", systemImage: "sparkles")
                .font(.display(.title3))
                .foregroundStyle(Theme.plum)
            Text("Gemini looks at this audience and funnel and suggests the next challenge to sponsor.")
                .font(.app(.caption))
                .foregroundStyle(.secondary)

            Button {
                Task { await generate() }
            } label: {
                HStack {
                    if loading { ProgressView().tint(.white) } else { Image(systemName: "sparkles") }
                    Text(loading ? "Thinking…" : (ideas.isEmpty ? "Suggest campaigns" : "Suggest more"))
                }
            }
            .buttonStyle(PrimaryButtonStyle(background: Theme.plumFixed))
            .disabled(loading)

            if let error {
                Text(error).font(.app(.footnote)).foregroundStyle(.red)
            }

            ForEach(ideas) { idea in
                VStack(alignment: .leading, spacing: 4) {
                    Text(idea.title).font(.app(.subheadline, weight: .bold))
                    Text(idea.challenge).font(.app(.subheadline))
                    Label(idea.audience, systemImage: "scope").font(.app(.caption, weight: .semibold)).foregroundStyle(Theme.teal)
                    Text(idea.why).font(.app(.caption)).foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !ideas.isEmpty {
                Text(fromGemini ? "Suggested by Gemini" : "Offline demo ideas. Add a Gemini key for live suggestions.")
                    .font(.app(.caption2))
                    .foregroundStyle(.secondary)
            }
        }
        .card()
        .onChange(of: campaign.id) { ideas = []; error = nil }
    }

    private struct Reply: Decodable { var ideas: [CampaignIdea] }

    private func generate() async {
        loading = true
        error = nil
        defer { loading = false }
        guard let client = GeminiClient.configured else {
            try? await Task.sleep(for: .seconds(1))
            withAnimation { ideas = offlineIdeas; fromGemini = false }
            return
        }
        let prompt = """
        You are a growth strategist for BuckIt, a Seattle social bucket-list app where brands sponsor challenges and reward
        people with coupons when they post a photo of completing them.

        Sponsor: \(campaign.sponsor.name)
        Current challenge: \(SeedData.challenge(campaign.challengeID)?.title ?? "")
        Audience rule: at least \(Int(campaign.threshold * 100))% of the person's bucket list is "\(campaign.targetCategory.label)"
        Marketed to: \(campaign.marketedTo) of \(campaign.cityUsers) Seattle users
        Funnel: \(campaign.addedToList) added to their list, \(campaign.waitingForCoupon) submitted and waiting, \(campaign.redeemed) redeemed
        Top neighborhoods: \(campaign.neighborhoods.map(\.0).joined(separator: ", "))
        Activity types available: \(ChallengeCategory.allCases.map(\.label).joined(separator: ", "))

        Suggest 3 new sponsored challenges for this brand in Seattle. Respond with strict JSON only:
        {"ideas": [{"title": string (campaign name, max 5 words), "challenge": string (what people do, one sentence),
                    "audience": string (who to target, e.g. "≥50% Outdoors in Ballard"), "why": string (one sentence, cite the data)}]}
        """
        do {
            let reply = try await client.generate(Reply.self, prompt: prompt)
            withAnimation { ideas = reply.ideas; fromGemini = true }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var offlineIdeas: [CampaignIdea] {
        let brand = campaign.sponsor.name
        let type = campaign.targetCategory.label
        let hood = campaign.neighborhoods.first?.0 ?? "Seattle"
        return [
            CampaignIdea(title: "\(brand) Sunrise Series",
                         challenge: "Catch a sunrise from a Seattle viewpoint and post it before 8 am.",
                         audience: "≥\(Int(campaign.threshold * 100))% \(type), \(hood)",
                         why: "\(hood) is your biggest neighborhood, and early-morning posts are rare, so they stand out in feeds."),
            CampaignIdea(title: "Bring-a-Friend Bonus",
                         challenge: "Complete the current challenge with a tagged friend to unlock a second coupon.",
                         audience: "Your current audience + their tagged friends",
                         why: "Only \(Int(Double(campaign.redeemed) / Double(max(campaign.addedToList, 1)) * 100))% of people who added the task redeemed it; social accountability should lift that."),
            CampaignIdea(title: "Finish-Strong Reminder",
                         challenge: "A limited-time boost for the \(campaign.waitingForCoupon) people with an unused coupon.",
                         audience: "Submitted, coupon not yet used",
                         why: "They've already done the challenge, so a nudge to redeem is the cheapest conversion in the funnel."),
        ]
    }
}
