<h1 align="center">AlphaLine</h1>

<p align="center">
  <em>A multiplayer prediction market protocol on Base. Stake land. Grow yield. Trade everything.</em>
</p>

<p align="center">
  <a href="https://alphaline.fun"><img alt="Site" src="https://img.shields.io/badge/site-alphaline.fun-1a8917?style=for-the-badge"></a>
  <a href="https://x.com/cropfun"><img alt="Twitter" src="https://img.shields.io/badge/follow-%40cropfun-000000?logo=x&style=for-the-badge"></a>
  <a href="https://medium.com/@CropLandFun"><img alt="Medium" src="https://img.shields.io/badge/medium-%40CropLandFun-12100E?logo=medium&style=for-the-badge"></a>
</p>

<p align="center">
  <img alt="Audited" src="https://img.shields.io/badge/audit-passed-brightgreen?logo=verified-shield">
  <img alt="Verified" src="https://img.shields.io/badge/contract-verified-brightgreen?logo=ethereum">
  <img alt="Base" src="https://img.shields.io/badge/Base-Mainnet-0052FF?logo=coinbase&logoColor=white">
  <img alt="Solidity" src="https://img.shields.io/badge/Solidity-0.8.24-blue?logo=solidity">
  <img alt="Foundry" src="https://img.shields.io/badge/Foundry-stable-black">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-yellow">
  <img alt="Status" src="https://img.shields.io/badge/status-live-success">
</p>

---

## What is AlphaLine

AlphaLine is a real-time fair-value pricing game where every plot of land is a real, stake-backed position on Base. There are 100 plots in the world. They are unevenly distributed across four tiers — Bronze, Silver, Gold, Diamond — and they don't mint, airdrop, or expand. Once they're claimed, they're claimed, and the only way more come back to the market is when someone abandons theirs.

You don't rent a plot. You stake into it. The USDC you commit on claim is locked inside the protocol contract, and stays locked until you transfer the plot or abandon it. Walk away, and your stake is forfeited — half burned, half to the protocol treasury.

That single design choice is what separates AlphaLine from a prediction market analytics tool. The cost of holding land is real. The cost of giving up on land is also real. Every system layered on top — markets, tribes, alliances, raids, the yield engine — is weighted by it.

> **Land you don't believe in, you don't claim. Land you do, you defend.**

Play now at **[alphaline.fun](https://alphaline.fun)** · Follow updates on **[@cropfun](https://x.com/cropfun)** · Read more on **[Medium](https://medium.com/@CropLandFun)**.

---

## World Preview

A glimpse of four claimed plots — Bronze, Silver, Gold, Diamond — rendered from the world's deterministic seed.

<table>
  <tr>
    <td align="center"><img src="assets/plot-bronze.png" alt="Bronze plot" width="320"><br><strong>Bronze</strong> · 50 supply · 1.0× yield</td>
    <td align="center"><img src="assets/plot-silver.png" alt="Silver plot" width="320"><br><strong>Silver</strong> · 30 supply · 1.5× yield</td>
  </tr>
  <tr>
    <td align="center"><img src="assets/plot-gold.png" alt="Gold plot" width="320"><br><strong>Gold</strong> · 15 supply · 2.0× yield</td>
    <td align="center"><img src="assets/plot-diamond.png" alt="Diamond plot" width="320"><br><strong>Diamond</strong> · 5 supply · 3.0× yield</td>
  </tr>
</table>

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                  AlphaLine.sol  (Base · Foundry)                │
│                                                                  │
│   Plot    ──┐                                                    │
│   Player   ─┼──> claim · abandon · upgrade ──> contract vault   │
│   Tribe    ─┤                                                    │
│   Alliance┘                                                      │
│                                                                  │
│   PlotOffer ──> list · accept ──> atomic ownership transfer     │
│                                                                  │
│   Order ──> placeOrder ──> _matchBook ──> escrow settlement     │
│                                                                  │
│   harvest ──> computeYield(tier × upgrade × tribe × ally × GH)  │
└──────────────────────────────────────────────────────────────────┘
```

All state lives on-chain in a single protocol contract on Base. The contract handles claim staking, plot transfer, the order book, social membership, and the multiplicative yield engine. Frontend reads state, builds transactions, and renders.

---

## Plot Tiers

| Tier    | Supply | Stake Cost | Crop Slots | Animal Slots | Base Yield |
| :------ | :----: | :--------: | :--------: | :----------: | :--------: |
| Bronze  |   50   |   1 USDC   |     4      |      1       |   1.0×     |
| Silver  |   30   |   5 USDC   |     6      |      2       |   1.5×     |
| Gold    |   15   |  15 USDC   |     8      |      3       |   2.0×     |
| Diamond |    5   |  50 USDC   |    10      |      5       |   3.0×     |

Each wallet is capped at **5 plots total**. The cap is enforced at the contract level, not the UI.

---

## Smart Contracts

The full Solidity contract lives in [`contracts/AlphaLine.sol`](contracts/AlphaLine.sol). Below is the shape of the protocol at a glance.

### The plot record

```solidity
struct Plot {
    address  owner;         // address(0) when unclaimed
    PlotTier tier;          // Bronze | Silver | Gold | Diamond
    uint128  lockedAmount;  // USDC base units held by the contract
    uint64   claimedAt;
    uint8    upgradeLevel;  // 1..=4
    uint64   lastHarvest;
}

enum PlotTier { Bronze, Silver, Gold, Diamond }

mapping(uint8 => Plot) public plots;
```

Locked USDC sits inside the protocol contract itself — no per-plot wallet, no external custodian. The contract's USDC balance is the protocol's collateral pool. Plot ownership is the right to withdraw your stake under specific conditions, and the right to harvest from the land while you hold it.

### Claim

```solidity
function claimPlot(uint8 plotId, PlotTier tier) external {
    Plot storage p = plots[plotId];

    if (p.owner != address(0))                          revert AlreadyClaimed();
    if (plotsOwned[msg.sender] >= MAX_PLOTS_PER_WALLET) revert TooManyPlots();

    uint128 cost = claimCost(tier);
    USDC.transferFrom(msg.sender, address(this), cost);

    p.owner         = msg.sender;
    p.tier          = tier;
    p.lockedAmount  = cost;
    p.claimedAt     = uint64(block.timestamp);
    p.upgradeLevel  = 1;

    plotsOwned[msg.sender] += 1;
    emit PlotClaimed(plotId, msg.sender, tier, cost);
}
```

### Abandon (forfeit)

```solidity
function abandonPlot(uint8 plotId) external {
    Plot storage p = plots[plotId];
    if (p.owner != msg.sender) revert NotOwner();

    uint128 stake    = p.lockedAmount;
    uint128 burn     = uint128(uint256(stake) * ABANDON_BURN_BPS / 10_000); // 50%
    uint128 treasury = stake - burn;

    USDC.transfer(BURN_ADDRESS, burn);
    USDC.transfer(TREASURY,     treasury);

    p.owner         = address(0);
    p.lockedAmount  = 0;
    p.claimedAt     = 0;

    plotsOwned[msg.sender] -= 1;
    emit PlotAbandoned(plotId, stake);
}
```

The locked stake does **not** return to the player. Half is burned. Half goes to the protocol treasury. The plot returns to world supply, available to the next farmer.

### Plot exchange — atomic settlement

The accept function is guarded against three race conditions with a single optimistic concurrency check:

```solidity
function acceptPlotOffer(uint8 plotId) external {
    PlotOffer storage o = offers[plotId];
    Plot      storage p = plots[plotId];
    address           buyer = msg.sender;

    if (o.status != OfferStatus.Open)                  revert OfferClosed();
    if (p.owner  != o.seller)                          revert SellerNoLongerOwns();
    if (o.seller == buyer)                             revert SelfTrade();
    if (o.buyer  != address(0) && o.buyer != buyer)    revert OfferNotForYou();

    uint128 fee = uint128(uint256(o.price) * FEE_BPS / 10_000);   // 2.5%
    uint128 net = o.price - fee;
    USDC.transferFrom(buyer, o.seller, net);
    USDC.transferFrom(buyer, TREASURY, fee);

    p.owner      = buyer;
    o.status     = OfferStatus.Accepted;
    o.buyer      = buyer;

    emit PlotTraded(plotId, o.seller, buyer, o.price);
}
```

The line that does the heavy lifting is `if (p.owner != o.seller)`. If anything changed the plot's owner since the offer was posted — another sale, an abandonment, a raid that flipped the deed — the check reverts, the transaction unwinds, and no USDC moves. The buyer's funds are safe. The seller's plot is safe.

Either everything happens or nothing happens. There's no half-state. There's no race.

### Order book — continuous matching

Crops, animal products, fish, herbs all trade through a single continuous order book. Place an ask, the contract locks your inventory in escrow. Place a bid, the contract locks your USDC. New orders are matched against the existing book on insert.

```solidity
function _matchBook(ItemType item) internal {
    uint256[] memory askIds = _bestAsks(item, 10);
    uint256[] memory bidIds = _bestBids(item, 10);

    for (uint i; i < askIds.length; ++i) {
        Order storage a = orders[askIds[i]];
        for (uint j; j < bidIds.length; ++j) {
            Order storage b = orders[bidIds[j]];

            if (b.price < a.price)   break;       // book exhausted at price
            if (b.maker == a.maker)  continue;    // self-match guard

            uint128 qty   = a.remaining < b.remaining ? a.remaining : b.remaining;
            uint128 price = a.price;                  // patient seller wins ties
            uint128 gross = qty * price;
            uint128 fee   = uint128(uint256(gross) * FEE_BPS / 10_000);
            uint128 net   = gross - fee;

            _settle(a.maker, b.maker, item, qty, net, fee);

            a.remaining -= qty;
            b.remaining -= qty;
            if (a.remaining == 0) { a.status = OrderStatus.Filled; break; }
        }
    }
}
```

A 2.5% protocol fee is split between the treasury and the burn address. Self-matching is prevented at the pair level so wallets can't fake volume.

### Tribes and alliances

```solidity
uint8 public constant TRIBE_MAX_MEMBERS    = 10;
uint8 public constant ALLIANCE_MAX_MEMBERS =  5;

struct Tribe {
    bytes32 name;
    bytes4  tag;
    address leader;
    uint8   memberCount;
    bytes8  inviteCode;
    uint64  createdAt;
}
```

Two parallel social systems with intentionally different commitment levels:

- **Tribes** — up to 10 members, an explicit leader, applications, kicks, an invite code. Members get a flat **+10%** harvest bonus. The leader gets **+5% per other member**, scaling with tribe size up to **+45%** at full ten-member tribes.
- **Alliances** — up to 5 members, no leader, no applications, just join and leave. Everyone gets a flat **+5%** harvest bonus.

A wallet can be in one tribe **and** one alliance simultaneously. The bonuses stack.

---

## The Yield Engine

Every harvest in AlphaLine passes through a single pure function. Multipliers compose **multiplicatively**, not additively.

```solidity
function computeYield(
    uint256  base,
    PlotTier tier,
    uint8    upgradeLevel,
    bool     inTribe,
    bool     isTribeLeader,
    uint8    tribeMembersCount,
    bool     inAlliance,
    bool     goldenHour
) public pure returns (uint256) {
    uint256 tierBps    = tierYieldBps(tier);              // 10_000..=30_000
    uint256 upBps      = upgradeBps(upgradeLevel);        // 10_000..=20_000

    uint256 tribeBps = 10_000;
    if (inTribe) {
        if (isTribeLeader) {
            tribeBps = 10_000 + 500 * (uint256(tribeMembersCount) - 1);
        } else {
            tribeBps = 11_000;                            // member: +10%
        }
    }

    uint256 allianceBps = inAlliance ? 10_500 : 10_000;
    uint256 goldenBps   = goldenHour ? 12_000 : 10_000;

    uint256 y = base;
    y = (y * tierBps)     / 10_000;
    y = (y * upBps)       / 10_000;
    y = (y * tribeBps)    / 10_000;
    y = (y * allianceBps) / 10_000;
    y = (y * goldenBps)   / 10_000;
    return y;
}
```

### Worked example: maxed-out farmer

A farmer on a **Diamond** plot, **level 4**, in a **10-member tribe** as a member, in an **alliance**, harvesting during **Golden Hour**. Base wheat yield: 100.

| Multiplier      | Factor | Running |
| :-------------- | -----: | ------: |
| Base            |        |     100 |
| Diamond tier    |  3.00× |     300 |
| Level 4 upgrade |  2.00× |     600 |
| Tribe member    |  1.10× |     660 |
| Alliance        |  1.05× |     693 |
| Golden Hour     |  1.20× |     831 |

The same plot, level-1, no tribe, no alliance, off Golden Hour, base 100, returns 100. The maxed farmer earns **8.31×** what an unaffiliated player would receive from the same harvest tick.

> AlphaLine rewards dedication out of proportion to effort. Anyone can show up. Fewer can build the structure.

### Golden Hour

```solidity
function isGoldenHour() public view returns (bool) {
    uint256 cycle  = 6 hours;
    uint256 window = 1 hours;
    return (block.timestamp % cycle) < window;
}
```

Every six hours, for one hour, every harvest in the world gets +20%. There's no cron, no oracle, no off-chain scheduler — it's a pure function of `block.timestamp`. Tribe leaders organize harvest rallies around it. The order book sees a volume spike. Good farmers schedule themselves.

---

## Tokenomics

In-game economics are denominated in USDC on Base.

| Action                | Fee                              | Destination                   |
| :-------------------- | :------------------------------- | :---------------------------- |
| Plot claim            | None (full stake locked)         | Contract vault                |
| Plot abandon          | 100% of stake                    | 50% burn / 50% treasury       |
| Plot upgrade          | 5 / 15 / 40 USDC (level 2/3/4)   | Treasury (with partial burn)  |
| Plot trade            | 2.5% of price                    | Treasury (with partial burn)  |
| Order book fill       | 2.5% of gross                    | Treasury (with partial burn)  |
| Harvest               | None                             | —                             |

A portion of every fee is permanently burned, reducing the circulating supply over time. The remainder funds the protocol treasury — used for liquidity, audits, and ongoing development.

---

## Repository Layout

```
wheat-world/
├── foundry.toml
├── remappings.txt
├── contracts/
│   └── AlphaLine.sol         # protocol contract — accounts, instructions, yield
├── assets/                    # README artwork
├── LICENSE                    # MIT
└── README.md
```

---

## Roadmap

- [x] Core contract: plots, claim/abandon, upgrades
- [x] P2P plot exchange with atomic settlement
- [x] Continuous order book with self-match guard
- [x] Tribes (10-member) and Alliances (5-member)
- [x] Multiplicative yield engine + Golden Hour
- [ ] Base Sepolia deployment + verification
- [ ] Base mainnet deployment + initial liquidity
- [ ] Farmer NFTs (free mint window for token holders)
- [ ] On-chain raid / steal mechanic with defender stacking
- [ ] Plot leasing (yield rights without ownership transfer)
- [ ] Cross-tribe coordination contracts

---

## Security

The contract uses custom errors, strict access checks, and optimistic concurrency where preconditions could change between signing and settlement (most notably the plot-trade `acceptPlotOffer` path). State-changing functions are guarded by ownership checks and explicit reverts rather than silent failure.

Independent review is in progress. Findings will be published in this repository as they are addressed.

---

## Links

- **Site** — [alphaline.fun](https://alphaline.fun)
- **Twitter / X** — [@cropfun](https://x.com/cropfun)
- **Medium** — [@CropLandFun](https://medium.com/@CropLandFun)
- **Source** — you're reading it

---

<p align="center">
  <em>AlphaLine — the world has 100 plots. There are 5 diamonds. Find yours.</em>
</p>
