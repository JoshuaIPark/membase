// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 ─────────────────────────────────────────────────────────────────────────────
 AlphaLine — on-chain settlement layer for sports prediction markets.

 Purpose:  Verify and settle resolved edge signals on-chain.
 Venue:    Polymarket-native. Works alongside the gamma-api and CLOB.
 Signals:  injury · lineup · sharp · weather · sentiment · rest · travel
 Edge:     marketProb vs alphaProb — the gap is the opportunity.
 ─────────────────────────────────────────────────────────────────────────────
*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AlphaLine {

    // ═══════════════════════════════════════ CONSTANTS ════════════════════
    uint256 public constant MIN_EDGE_BPS       = 300;   // 3% minimum edge to settle
    uint256 public constant HIGH_CONF_BPS      = 700;   // 7% high-confidence threshold
    uint256 public constant PROTOCOL_FEE_BPS   = 150;   // 1.5% on settled payouts
    uint256 public constant SIGNAL_TTL         = 2 hours;

    // ═══════════════════════════════════════ TYPES ════════════════════════
    enum Sport        { NBA, NHL, MLB, NFL }
    enum SignalType   { Injury, Lineup, Sharp, Weather, Sentiment, Rest, Travel }
    enum MarketStatus { Pending, Live, Settled, Cancelled }

    struct Signal {
        SignalType  signalType;
        uint256     marketProb;
        uint256     alphaProb;
        uint256     timestamp;
        bool        resolved;
    }

    struct Market {
        bytes32      id;
        Sport        sport;
        string       game;
        string       pick;
        MarketStatus status;
        uint256      volumeUsdc;
        uint256      settledAt;
        bool         result;
    }

    struct EdgeAlert {
        bytes32    marketId;
        uint256    edgeBps;
        SignalType trigger;
        uint256    firedAt;
        address    reporter;
    }

    // ═══════════════════════════════════════ STORAGE ══════════════════════
    IERC20  public immutable usdc;
    address public immutable treasury;
    address public           owner;

    mapping(bytes32 => Market)      public markets;
    mapping(bytes32 => Signal[])    public signals;
    mapping(bytes32 => EdgeAlert[]) public alerts;

    bytes32[] public allMarkets;

    // ═══════════════════════════════════════ EVENTS ═══════════════════════
    event MarketCreated(bytes32 indexed id, Sport sport, string game);
    event SignalFiled(bytes32 indexed marketId, SignalType signalType, uint256 edgeBps);
    event EdgeAlertFired(bytes32 indexed marketId, uint256 edgeBps, address reporter);
    event MarketSettled(bytes32 indexed marketId, bool result, uint256 settledAt);
    event OwnershipTransferred(address indexed previous, address indexed next);

    // ═══════════════════════════════════════ ERRORS ═══════════════════════
    error Unauthorized();
    error MarketNotFound();
    error MarketAlreadySettled();
    error MarketNotLive();
    error EdgeBelowMinimum(uint256 edgeBps, uint256 minBps);
    error InvalidProbability();

    // ═══════════════════════════════════════ CONSTRUCTOR ══════════════════
    constructor(IERC20 _usdc, address _treasury) {
        usdc     = _usdc;
        treasury = _treasury;
        owner    = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier marketExists(bytes32 id) {
        if (markets[id].id == bytes32(0)) revert MarketNotFound();
        _;
    }

    // ═══════════════════════════════════════ MARKET LIFECYCLE ═════════════
    function createMarket(
        bytes32 id,
        Sport   sport,
        string calldata game,
        string calldata pick
    ) external onlyOwner {
        markets[id] = Market({
            id: id, sport: sport, game: game, pick: pick,
            status: MarketStatus.Live, volumeUsdc: 0, settledAt: 0, result: false
        });
        allMarkets.push(id);
        emit MarketCreated(id, sport, game);
    }

    function fileSignal(
        bytes32    marketId,
        SignalType signalType,
        uint256    marketProb,
        uint256    alphaProb
    ) external marketExists(marketId) {
        if (markets[marketId].status != MarketStatus.Live) revert MarketNotLive();
        if (marketProb > 10_000 || alphaProb > 10_000)    revert InvalidProbability();

        uint256 edgeBps = alphaProb > marketProb
            ? alphaProb - marketProb
            : marketProb - alphaProb;

        if (edgeBps < MIN_EDGE_BPS) revert EdgeBelowMinimum(edgeBps, MIN_EDGE_BPS);

        signals[marketId].push(Signal({
            signalType: signalType, marketProb: marketProb,
            alphaProb: alphaProb, timestamp: block.timestamp, resolved: false
        }));
        alerts[marketId].push(EdgeAlert({
            marketId: marketId, edgeBps: edgeBps, trigger: signalType,
            firedAt: block.timestamp, reporter: msg.sender
        }));

        emit SignalFiled(marketId, signalType, edgeBps);
        emit EdgeAlertFired(marketId, edgeBps, msg.sender);
    }

    function settleMarket(bytes32 id, bool won)
        external onlyOwner marketExists(id)
    {
        Market storage m = markets[id];
        if (m.status == MarketStatus.Settled) revert MarketAlreadySettled();
        m.status    = MarketStatus.Settled;
        m.result    = won;
        m.settledAt = block.timestamp;
        emit MarketSettled(id, won, block.timestamp);
    }

    // ═══════════════════════════════════════ VIEWS ════════════════════════
    function getMarket(bytes32 id) external view returns (Market memory) {
        return markets[id];
    }

    function getSignals(bytes32 marketId) external view returns (Signal[] memory) {
        return signals[marketId];
    }

    function getAlerts(bytes32 marketId) external view returns (EdgeAlert[] memory) {
        return alerts[marketId];
    }

    function marketCount() external view returns (uint256) {
        return allMarkets.length;
    }

    function edge(bytes32 marketId) external view returns (uint256) {
        Signal[] storage sigs = signals[marketId];
        if (sigs.length == 0) return 0;
        Signal storage s = sigs[sigs.length - 1];
        return s.alphaProb > s.marketProb
            ? s.alphaProb - s.marketProb
            : s.marketProb - s.alphaProb;
    }

    function transferOwnership(address next) external onlyOwner {
        emit OwnershipTransferred(owner, next);
        owner = next;
    }
}
