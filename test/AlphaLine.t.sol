// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AlphaLine}     from "../contracts/AlphaLine.sol";
import {MockERC20}     from "./mocks/MockERC20.sol";

contract AlphaLineTest is Test {
    AlphaLine public alphaline;
    MockERC20 public usdc;

    address public owner    = address(this);
    address public reporter = address(0xA11CE);
    address public treasury = address(0x7E5);

    bytes32 constant MARKET_ID = keccak256("nyk-okc-finals-g5");

    function setUp() public {
        usdc       = new MockERC20("USD Coin", "USDC", 6);
        alphaline  = new AlphaLine(usdc, treasury);
    }

    // ─────────────────────────────── createMarket ─────────────────────────

    function test_createMarket() public {
        alphaline.createMarket(
            MARKET_ID,
            AlphaLine.Sport.NBA,
            "Knicks @ Thunder - Finals G5",
            "Will Thunder win the championship?"
        );

        AlphaLine.Market memory m = alphaline.getMarket(MARKET_ID);
        assertEq(m.id, MARKET_ID);
        assertEq(uint8(m.sport), uint8(AlphaLine.Sport.NBA));
        assertEq(uint8(m.status), uint8(AlphaLine.MarketStatus.Live));
        assertEq(alphaline.marketCount(), 1);
    }

    function test_createMarket_onlyOwner() public {
        vm.prank(reporter);
        vm.expectRevert(AlphaLine.Unauthorized.selector);
        alphaline.createMarket(MARKET_ID, AlphaLine.Sport.NBA, "game", "pick");
    }

    // ─────────────────────────────── fileSignal ───────────────────────────

    function test_fileSignal_emitsEdgeAlert() public {
        _createMarket();

        vm.expectEmit(true, false, false, true);
        emit AlphaLine.EdgeAlertFired(MARKET_ID, 900, reporter);

        vm.prank(reporter);
        alphaline.fileSignal(
            MARKET_ID,
            AlphaLine.SignalType.Injury,
            7_600, // marketProb 76%
            8_500  // alphaProb  85% → edge 900bps
        );
    }

    function test_fileSignal_belowMinEdge_reverts() public {
        _createMarket();
        vm.prank(reporter);
        vm.expectRevert();
        alphaline.fileSignal(
            MARKET_ID,
            AlphaLine.SignalType.Sharp,
            5_000, // marketProb 50%
            5_100  // alphaProb  51% → edge 100bps < 300bps min
        );
    }

    function test_fileSignal_invalidProb_reverts() public {
        _createMarket();
        vm.prank(reporter);
        vm.expectRevert(AlphaLine.InvalidProbability.selector);
        alphaline.fileSignal(MARKET_ID, AlphaLine.SignalType.Lineup, 10_001, 5_000);
    }

    function test_edge_returnsLatestSignalEdge() public {
        _createMarket();
        vm.prank(reporter);
        alphaline.fileSignal(MARKET_ID, AlphaLine.SignalType.Rest, 6_300, 7_200);

        uint256 e = alphaline.edge(MARKET_ID);
        assertEq(e, 900); // 7200 - 6300
    }

    // ─────────────────────────────── settleMarket ─────────────────────────

    function test_settleMarket_won() public {
        _createMarket();
        alphaline.settleMarket(MARKET_ID, true);

        AlphaLine.Market memory m = alphaline.getMarket(MARKET_ID);
        assertEq(uint8(m.status), uint8(AlphaLine.MarketStatus.Settled));
        assertTrue(m.result);
        assertGt(m.settledAt, 0);
    }

    function test_settleMarket_alreadySettled_reverts() public {
        _createMarket();
        alphaline.settleMarket(MARKET_ID, true);
        vm.expectRevert(AlphaLine.MarketAlreadySettled.selector);
        alphaline.settleMarket(MARKET_ID, false);
    }

    function test_settleMarket_onlyOwner() public {
        _createMarket();
        vm.prank(reporter);
        vm.expectRevert(AlphaLine.Unauthorized.selector);
        alphaline.settleMarket(MARKET_ID, true);
    }

    // ─────────────────────────────── ownership ────────────────────────────

    function test_transferOwnership() public {
        alphaline.transferOwnership(reporter);
        assertEq(alphaline.owner(), reporter);
    }

    // ─────────────────────────────── helpers ──────────────────────────────

    function _createMarket() internal {
        alphaline.createMarket(
            MARKET_ID,
            AlphaLine.Sport.NBA,
            "Knicks @ Thunder - Finals G5",
            "Will Thunder win the championship?"
        );
    }
}
