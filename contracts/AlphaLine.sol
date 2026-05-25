// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 ─────────────────────────────────────────────────────────────────────────────
 AlphaLine — a multiplayer prediction market protocol on Base.

 World:    100 plots, four tiers, finite supply.
 Stake:    USDC locked into the contract on claim; forfeit on abandon.
 Markets:  P2P plot exchange + continuous order book for crops.
 Social:   Tribes (10 members, leader/member yield split) and Alliances
           (5 members, flat yield bonus).
 Yield:    Multiplicative — tier × upgrade × tribe × alliance × goldenHour.
 ─────────────────────────────────────────────────────────────────────────────
*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBurnable {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract AlphaLine {

    // ═════════════════════════════════════════════════════════════════════════
    //                              CONSTANTS
    // ═════════════════════════════════════════════════════════════════════════

    uint8   public constant WORLD_PLOTS           = 100;
    uint8   public constant MAX_PLOTS_PER_WALLET  = 5;
    uint8   public constant TRIBE_MAX_MEMBERS     = 10;
    uint8   public constant ALLIANCE_MAX_MEMBERS  = 5;

    // Protocol fees, expressed in basis points of 10_000.
    uint256 public constant FEE_BPS               = 250;     // 2.5% on filled trades
    uint256 public constant ABANDON_BURN_BPS      = 5_000;   // 50% of stake burned
    uint256 public constant ABANDON_TREASURY_BPS  = 5_000;   // 50% to treasury

    // Yield engine.
    uint256 public constant GOLDEN_HOUR_CYCLE     = 6 hours;
    uint256 public constant GOLDEN_HOUR_WINDOW    = 1 hours;
    uint256 public constant GOLDEN_HOUR_BPS       = 12_000;  // 1.20×

    uint256 public constant TRIBE_MEMBER_BPS         = 11_000;  // 1.10×
    uint256 public constant TRIBE_LEADER_PER_MEMBER  = 500;     // +5% per other member
    uint256 public constant ALLIANCE_BONUS_BPS       = 10_500;  // 1.05×

    uint256 public constant HARVEST_COOLDOWN      = 60;      // anti-spam floor

    address public constant BURN_ADDRESS = address(0xdEaD);

    // ═════════════════════════════════════════════════════════════════════════
    //                                STATE
    // ═════════════════════════════════════════════════════════════════════════

    enum PlotTier    { Bronze, Silver, Gold, Diamond }
    enum OfferStatus { Open, Accepted, Cancelled }
    enum Side        { Bid, Ask }
    enum OrderStatus { Open, Filled, Cancelled }
    enum ItemType    {
        Wheat, Corn, Pumpkin, Egg, Milk, Wool, Honey, Truffle, MagicHerb, Fish
    }

    struct Plot {
        address  owner;          // address(0) when unclaimed
        PlotTier tier;
        uint128  lockedAmount;   // USDC base units
        uint64   claimedAt;
        uint8    upgradeLevel;   // 1..=4
        uint64   lastHarvest;
    }

    struct PlotOffer {
        address     seller;
        address     buyer;       // address(0) = open market, non-zero = targeted
        uint128     price;       // USDC base units
        OfferStatus status;
        uint64      createdAt;
    }

    struct Order {
        address     maker;
        ItemType    item;
        Side        side;
        uint128     quantity;
        uint128     remaining;
        uint128     price;       // USDC per unit
        OrderStatus status;
        uint64      createdAt;
    }

    struct Tribe {
        bytes32 name;
        bytes4  tag;
        address leader;
        uint8   memberCount;     // 1..=TRIBE_MAX_MEMBERS
        bytes8  inviteCode;
        uint64  createdAt;
    }

    struct TribeMember {
        uint256 tribeId;
        uint64  joinedAt;
        bool    isLeader;
    }

    struct Alliance {
        bytes32 name;
        uint8   memberCount;     // 1..=ALLIANCE_MAX_MEMBERS
        uint64  createdAt;
    }

    // Mappings
    mapping(uint8   => Plot)         public plots;          // plot id -> Plot
    mapping(uint8   => PlotOffer)    public offers;         // plot id -> offer
    mapping(uint256 => Order)        public orders;
    mapping(uint256 => Tribe)        public tribes;
    mapping(uint256 => mapping(address => TribeMember)) public tribeMembers;
    mapping(uint256 => Alliance)     public alliances;
    mapping(uint256 => mapping(address => uint64)) public allianceJoinedAt;
    mapping(address => uint8)        public plotsOwned;

    uint256 public nextOrderId;
    uint256 public nextTribeId;
    uint256 public nextAllianceId;

    IERC20  public immutable USDC;
    address public immutable TREASURY;

    // ═════════════════════════════════════════════════════════════════════════
    //                                ERRORS
    // ═════════════════════════════════════════════════════════════════════════

    error AlreadyClaimed();
    error NotClaimed();
    error NotOwner();
    error TooManyPlots();
    error UpgradeMaxed();
    error OfferClosed();
    error SellerNoLongerOwns();
    error SelfTrade();
    error OfferNotForYou();
    error InvalidOrder();
    error TribeFull();
    error AllianceFull();
    error AlreadyMember();
    error NotMember();
    error NotLeader();
    error HarvestCooldown();
    error InvalidTier();

    // ═════════════════════════════════════════════════════════════════════════
    //                                EVENTS
    // ═════════════════════════════════════════════════════════════════════════

    event PlotClaimed   (uint8 indexed plotId, address indexed owner, PlotTier tier, uint128 stake);
    event PlotAbandoned (uint8 indexed plotId, uint128 forfeit);
    event PlotUpgraded  (uint8 indexed plotId, uint8 newLevel);
    event PlotTraded    (uint8 indexed plotId, address indexed seller, address indexed buyer, uint128 price);
    event OrderFilled   (uint256 indexed askId, uint256 indexed bidId, uint128 qty, uint128 price, uint128 fee, uint128 net);
    event TribeCreated  (uint256 indexed tribeId, address indexed leader, bytes32 name);
    event TribeJoined   (uint256 indexed tribeId, address indexed wallet);
    event AllianceCreated(uint256 indexed allianceId, bytes32 name);
    event AllianceJoined(uint256 indexed allianceId, address indexed wallet);
    event Harvested     (uint8 indexed plotId, address indexed owner, uint256 amount, bool goldenHour);

    // ═════════════════════════════════════════════════════════════════════════
    //                            CONSTRUCTOR
    // ═════════════════════════════════════════════════════════════════════════

    constructor(IERC20 usdc, address treasury) {
        USDC     = usdc;
        TREASURY = treasury;
    }

    // ═════════════════════════════════════════════════════════════════════════
    //                                 PLOTS
    // ═════════════════════════════════════════════════════════════════════════

    function claimCost(PlotTier tier) public pure returns (uint128) {
        if (tier == PlotTier.Bronze)  return  1e6;   //  1 USDC
        if (tier == PlotTier.Silver)  return  5e6;   //  5 USDC
        if (tier == PlotTier.Gold)    return 15e6;   // 15 USDC
        if (tier == PlotTier.Diamond) return 50e6;   // 50 USDC
        revert InvalidTier();
    }

    function tierYieldBps(PlotTier tier) public pure returns (uint256) {
        if (tier == PlotTier.Bronze)  return 10_000;   // 1.0×
        if (tier == PlotTier.Silver)  return 15_000;   // 1.5×
        if (tier == PlotTier.Gold)    return 20_000;   // 2.0×
        if (tier == PlotTier.Diamond) return 30_000;   // 3.0×
        revert InvalidTier();
    }

    function upgradeBps(uint8 level) public pure returns (uint256) {
        if (level == 1) return 10_000;
        if (level == 2) return 12_500;
        if (level == 3) return 15_000;
        if (level == 4) return 20_000;
        return 10_000;
    }

    function upgradeCost(uint8 level) public pure returns (uint128) {
        if (level == 2) return  5e6;
        if (level == 3) return 15e6;
        if (level == 4) return 40e6;
        return 0;
    }

    function claimPlot(uint8 plotId, PlotTier tier) external {
        Plot storage p = plots[plotId];

        if (p.owner != address(0))            revert AlreadyClaimed();
        if (plotsOwned[msg.sender] >= MAX_PLOTS_PER_WALLET) revert TooManyPlots();

        uint128 cost = claimCost(tier);
        USDC.transferFrom(msg.sender, address(this), cost);

        p.owner         = msg.sender;
        p.tier          = tier;
        p.lockedAmount  = cost;
        p.claimedAt     = uint64(block.timestamp);
        p.upgradeLevel  = 1;
        p.lastHarvest   = 0;

        plotsOwned[msg.sender] += 1;
        emit PlotClaimed(plotId, msg.sender, tier, cost);
    }

    function abandonPlot(uint8 plotId) external {
        Plot storage p = plots[plotId];
        if (p.owner != msg.sender) revert NotOwner();

        uint128 stake    = p.lockedAmount;
        uint128 burn     = uint128(uint256(stake) * ABANDON_BURN_BPS     / 10_000);
        uint128 treasury = stake - burn;

        USDC.transfer(BURN_ADDRESS, burn);
        USDC.transfer(TREASURY,     treasury);

        p.owner         = address(0);
        p.lockedAmount  = 0;
        p.claimedAt     = 0;
        p.upgradeLevel  = 1;

        plotsOwned[msg.sender] -= 1;
        emit PlotAbandoned(plotId, stake);
    }

    function upgradePlot(uint8 plotId) external {
        Plot storage p = plots[plotId];
        if (p.owner != msg.sender) revert NotOwner();
        if (p.upgradeLevel >= 4)   revert UpgradeMaxed();

        uint8   next = p.upgradeLevel + 1;
        uint128 cost = upgradeCost(next);
        USDC.transferFrom(msg.sender, TREASURY, cost);

        p.upgradeLevel = next;
        emit PlotUpgraded(plotId, next);
    }

    // ═════════════════════════════════════════════════════════════════════════
    //                            PLOT EXCHANGE
    // ═════════════════════════════════════════════════════════════════════════

    function listPlot(uint8 plotId, uint128 price, address targetBuyer) external {
        if (plots[plotId].owner != msg.sender) revert NotOwner();
        if (price == 0)                        revert InvalidOrder();

        offers[plotId] = PlotOffer({
            seller:    msg.sender,
            buyer:     targetBuyer,
            price:     price,
            status:    OfferStatus.Open,
            createdAt: uint64(block.timestamp)
        });
    }

    function acceptPlotOffer(uint8 plotId) external {
        PlotOffer storage o = offers[plotId];
        Plot      storage p = plots[plotId];
        address           buyer = msg.sender;

        if (o.status != OfferStatus.Open)                  revert OfferClosed();
        if (p.owner  != o.seller)                          revert SellerNoLongerOwns();
        if (o.seller == buyer)                             revert SelfTrade();
        if (o.buyer  != address(0) && o.buyer != buyer)    revert OfferNotForYou();

        // Protocol fee: 2.5%
        uint128 fee = uint128(uint256(o.price) * FEE_BPS / 10_000);
        uint128 net = o.price - fee;

        USDC.transferFrom(buyer, o.seller, net);
        USDC.transferFrom(buyer, TREASURY, fee);

        p.owner     = buyer;
        p.claimedAt = uint64(block.timestamp);

        o.status = OfferStatus.Accepted;
        o.buyer  = buyer;

        emit PlotTraded(plotId, o.seller, buyer, o.price);
    }

    function cancelPlotOffer(uint8 plotId) external {
        PlotOffer storage o = offers[plotId];
        if (o.seller != msg.sender)       revert NotOwner();
        if (o.status != OfferStatus.Open) revert OfferClosed();
        o.status = OfferStatus.Cancelled;
    }

    // ═════════════════════════════════════════════════════════════════════════
    //                         MARKETPLACE — ORDER BOOK
    // ═════════════════════════════════════════════════════════════════════════

    struct OrderArgs {
        ItemType item;
        Side     side;
        uint128  quantity;
        uint128  price;
    }

    function placeOrder(OrderArgs calldata a) external returns (uint256 id) {
        if (a.quantity == 0 || a.price == 0) revert InvalidOrder();

        id = ++nextOrderId;
        Order storage o = orders[id];
        o.maker     = msg.sender;
        o.item      = a.item;
        o.side      = a.side;
        o.quantity  = a.quantity;
        o.remaining = a.quantity;
        o.price     = a.price;
        o.status    = OrderStatus.Open;
        o.createdAt = uint64(block.timestamp);

        if (a.side == Side.Ask) {
            _lockItems(msg.sender, a.item, a.quantity);
        } else {
            uint128 lock = a.quantity * a.price;
            USDC.transferFrom(msg.sender, address(this), lock);
        }

        _matchBook(a.item);
    }

    /// Walk asks ascending, bids descending. Fill at the ask price (the patient
    /// seller wins ties). Stop when the books cross or one side is exhausted.
    /// Self-matching is prevented at the pair level.
    function _matchBook(ItemType item) internal {
        uint256[] memory askIds = _bestAsks(item, 10);
        uint256[] memory bidIds = _bestBids(item, 10);

        for (uint i; i < askIds.length; ++i) {
            Order storage a = orders[askIds[i]];
            if (a.status != OrderStatus.Open || a.item != item) continue;

            for (uint j; j < bidIds.length; ++j) {
                Order storage b = orders[bidIds[j]];
                if (b.status != OrderStatus.Open || b.item != item) continue;

                if (b.price < a.price)   break;
                if (b.maker == a.maker)  continue;       // self-match guard

                uint128 qty   = a.remaining < b.remaining ? a.remaining : b.remaining;
                uint128 price = a.price;
                uint128 gross = qty * price;
                uint128 fee   = uint128(uint256(gross) * FEE_BPS / 10_000);
                uint128 net   = gross - fee;

                _settle(a.maker, b.maker, item, qty, net, fee);

                a.remaining -= qty;
                b.remaining -= qty;
                if (a.remaining == 0) a.status = OrderStatus.Filled;
                if (b.remaining == 0) b.status = OrderStatus.Filled;

                emit OrderFilled(askIds[i], bidIds[j], qty, price, fee, net);
                if (a.remaining == 0) break;
            }
        }
    }

    function _lockItems(address from, ItemType item, uint128 qty) internal;
    function _bestAsks(ItemType item, uint8 k) internal view returns (uint256[] memory);
    function _bestBids(ItemType item, uint8 k) internal view returns (uint256[] memory);
    function _settle(address ask, address bid, ItemType item, uint128 qty, uint128 net, uint128 fee) internal;

    // ═════════════════════════════════════════════════════════════════════════
    //                                 SOCIAL
    // ═════════════════════════════════════════════════════════════════════════

    function createTribe(bytes32 name, bytes4 tag, bytes8 inviteCode) external returns (uint256 id) {
        id = ++nextTribeId;
        tribes[id] = Tribe({
            name:        name,
            tag:         tag,
            leader:      msg.sender,
            memberCount: 1,
            inviteCode:  inviteCode,
            createdAt:   uint64(block.timestamp)
        });
        tribeMembers[id][msg.sender] = TribeMember({
            tribeId:  id,
            joinedAt: uint64(block.timestamp),
            isLeader: true
        });
        emit TribeCreated(id, msg.sender, name);
    }

    function joinTribe(uint256 tribeId) external {
        Tribe storage t = tribes[tribeId];
        if (t.memberCount >= TRIBE_MAX_MEMBERS)        revert TribeFull();
        if (tribeMembers[tribeId][msg.sender].joinedAt != 0) revert AlreadyMember();

        tribeMembers[tribeId][msg.sender] = TribeMember({
            tribeId:  tribeId,
            joinedAt: uint64(block.timestamp),
            isLeader: false
        });
        t.memberCount += 1;
        emit TribeJoined(tribeId, msg.sender);
    }

    function createAlliance(bytes32 name) external returns (uint256 id) {
        id = ++nextAllianceId;
        alliances[id] = Alliance({
            name:        name,
            memberCount: 1,
            createdAt:   uint64(block.timestamp)
        });
        allianceJoinedAt[id][msg.sender] = uint64(block.timestamp);
        emit AllianceCreated(id, name);
    }

    function joinAlliance(uint256 allianceId) external {
        Alliance storage a = alliances[allianceId];
        if (a.memberCount >= ALLIANCE_MAX_MEMBERS)         revert AllianceFull();
        if (allianceJoinedAt[allianceId][msg.sender] != 0) revert AlreadyMember();

        allianceJoinedAt[allianceId][msg.sender] = uint64(block.timestamp);
        a.memberCount += 1;
        emit AllianceJoined(allianceId, msg.sender);
    }

    // ═════════════════════════════════════════════════════════════════════════
    //                                HARVEST
    // ═════════════════════════════════════════════════════════════════════════

    function isGoldenHour() public view returns (bool) {
        return (block.timestamp % GOLDEN_HOUR_CYCLE) < GOLDEN_HOUR_WINDOW;
    }

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
        uint256 tierBps    = tierYieldBps(tier);
        uint256 upBps      = upgradeBps(upgradeLevel);

        uint256 tribeBps = 10_000;
        if (inTribe) {
            if (isTribeLeader) {
                tribeBps = 10_000 + TRIBE_LEADER_PER_MEMBER * (uint256(tribeMembersCount) - 1);
            } else {
                tribeBps = TRIBE_MEMBER_BPS;
            }
        }

        uint256 allianceBps = inAlliance ? ALLIANCE_BONUS_BPS : 10_000;
        uint256 goldenBps   = goldenHour ? GOLDEN_HOUR_BPS    : 10_000;

        uint256 y = base;
        y = (y * tierBps)     / 10_000;
        y = (y * upBps)       / 10_000;
        y = (y * tribeBps)    / 10_000;
        y = (y * allianceBps) / 10_000;
        y = (y * goldenBps)   / 10_000;
        return y;
    }

    function harvest(
        uint8   plotId,
        uint256 baseAmount,
        bool    inTribe,
        bool    isTribeLeader,
        uint8   tribeMembersCount,
        bool    inAlliance
    ) external {
        Plot storage p = plots[plotId];
        if (p.owner != msg.sender)                             revert NotOwner();
        if (block.timestamp - p.lastHarvest < HARVEST_COOLDOWN) revert HarvestCooldown();

        bool golden = isGoldenHour();
        uint256 amount = computeYield(
            baseAmount,
            p.tier,
            p.upgradeLevel,
            inTribe,
            isTribeLeader,
            tribeMembersCount,
            inAlliance,
            golden
        );

        p.lastHarvest = uint64(block.timestamp);
        emit Harvested(plotId, msg.sender, amount, golden);
    }
}
