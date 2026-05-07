// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console}    from "forge-std/Test.sol";
import {AlphaLine}       from "../contracts/AlphaLine.sol";
import {MockERC20}        from "./mocks/MockERC20.sol";

contract AlphaLineTest is Test {
    AlphaLine public world;
    MockERC20  public usdc;

    address public alice    = address(0xA11CE);
    address public bob      = address(0xB0B);
    address public carol    = address(0xCA801);
    address public treasury = address(0x7E5);

    function setUp() public {
        usdc  = new MockERC20("USD Coin", "USDC", 6);
        world = new AlphaLine(usdc, treasury);

        usdc.mint(alice,  10_000e6);
        usdc.mint(bob,    10_000e6);
        usdc.mint(carol,  10_000e6);

        vm.prank(alice); usdc.approve(address(world), type(uint256).max);
        vm.prank(bob);   usdc.approve(address(world), type(uint256).max);
        vm.prank(carol); usdc.approve(address(world), type(uint256).max);
    }

    // ─────────────────────────── claim / abandon ───────────────────────────

    function test_claim_lockStakeToContract() public {
        vm.prank(alice);
        world.claimPlot(1, AlphaLine.PlotTier.Bronze);

        (address owner,, uint128 locked,,,) = world.plots(1);
        assertEq(owner,  alice);
        assertEq(locked, 1e6);
        assertEq(usdc.balanceOf(address(world)), 1e6);
    }

    function test_claim_revertsWhenAlreadyClaimed() public {
        vm.prank(alice); world.claimPlot(1, AlphaLine.PlotTier.Bronze);
        vm.prank(bob);
        vm.expectRevert(AlphaLine.AlreadyClaimed.selector);
        world.claimPlot(1, AlphaLine.PlotTier.Bronze);
    }

    function test_claim_enforces5PlotCap() public {
        for (uint8 i = 1; i <= 5; ++i) {
            vm.prank(alice); world.claimPlot(i, AlphaLine.PlotTier.Bronze);
        }
        vm.prank(alice);
        vm.expectRevert(AlphaLine.TooManyPlots.selector);
        world.claimPlot(6, AlphaLine.PlotTier.Bronze);
    }

    function test_abandon_burnsHalfAndSendsHalfToTreasury() public {
        vm.prank(alice); world.claimPlot(1, AlphaLine.PlotTier.Gold); // 15 USDC

        uint256 burnBefore = usdc.balanceOf(address(0xdEaD));
        uint256 tresBefore = usdc.balanceOf(treasury);

        vm.prank(alice); world.abandonPlot(1);

        assertEq(usdc.balanceOf(address(0xdEaD)) - burnBefore,  7.5e6);
        assertEq(usdc.balanceOf(treasury)        - tresBefore,  7.5e6);
        (address owner,,,,,) = world.plots(1);
        assertEq(owner, address(0));
    }

    function test_abandon_revertsForNonOwner() public {
        vm.prank(alice); world.claimPlot(1, AlphaLine.PlotTier.Bronze);
        vm.prank(bob);
        vm.expectRevert(AlphaLine.NotOwner.selector);
        world.abandonPlot(1);
    }

    // ─────────────────────────── upgrade ───────────────────────────────────

    function test_upgrade_progressesLevelAndChargesTreasury() public {
        vm.prank(alice); world.claimPlot(1, AlphaLine.PlotTier.Silver);

        uint256 tresBefore = usdc.balanceOf(treasury);
        vm.prank(alice); world.upgradePlot(1);   // 5 USDC -> level 2
        vm.prank(alice); world.upgradePlot(1);   // 15 USDC -> level 3
        vm.prank(alice); world.upgradePlot(1);   // 40 USDC -> level 4

        (, , , , uint8 level, ) = world.plots(1);
        assertEq(level, 4);
        assertEq(usdc.balanceOf(treasury) - tresBefore, 60e6);
    }

    function test_upgrade_revertsAtMax() public {
        vm.prank(alice); world.claimPlot(1, AlphaLine.PlotTier.Bronze);
        vm.prank(alice); world.upgradePlot(1);
        vm.prank(alice); world.upgradePlot(1);
        vm.prank(alice); world.upgradePlot(1);
        vm.prank(alice);
        vm.expectRevert(AlphaLine.UpgradeMaxed.selector);
        world.upgradePlot(1);
    }

    // ─────────────────────────── plot exchange ────────────────────────────

    function test_acceptPlotOffer_atomicTransferAndFee() public {
        vm.prank(alice); world.claimPlot(1, AlphaLine.PlotTier.Gold);
        vm.prank(alice); world.listPlot(1, 100e6, address(0));

        uint256 aliceBefore = usdc.balanceOf(alice);
        uint256 tresBefore  = usdc.balanceOf(treasury);

        vm.prank(bob); world.acceptPlotOffer(1);

        (address owner,,,,,) = world.plots(1);
        assertEq(owner, bob);
        assertEq(usdc.balanceOf(alice) - aliceBefore, 97.5e6);    // 100 - 2.5% fee
        assertEq(usdc.balanceOf(treasury) - tresBefore,  2.5e6);
    }

    function test_acceptPlotOffer_revertsIfSelfTrade() public {
        vm.prank(alice); world.claimPlot(1, AlphaLine.PlotTier.Bronze);
        vm.prank(alice); world.listPlot(1, 5e6, address(0));
        vm.prank(alice);
        vm.expectRevert(AlphaLine.SelfTrade.selector);
        world.acceptPlotOffer(1);
    }

    function test_acceptPlotOffer_revertsIfTargetedToOtherWallet() public {
        vm.prank(alice); world.claimPlot(1, AlphaLine.PlotTier.Bronze);
        vm.prank(alice); world.listPlot(1, 5e6, carol);    // only carol can accept

        vm.prank(bob);
        vm.expectRevert(AlphaLine.OfferNotForYou.selector);
        world.acceptPlotOffer(1);
    }

    // ─────────────────────────── tribes / alliances ────────────────────────

    function test_createAndJoinTribe() public {
        vm.prank(alice);
        uint256 tid = world.createTribe(bytes32("WheatBros"), bytes4("WBRS"), bytes8("INV-CODE"));

        vm.prank(bob);   world.joinTribe(tid);
        vm.prank(carol); world.joinTribe(tid);

        ( , , address leader, uint8 mc, , ) = world.tribes(tid);
        assertEq(leader, alice);
        assertEq(mc, 3);
    }

    function test_joinTribe_revertsWhenFull() public {
        vm.prank(alice);
        uint256 tid = world.createTribe(bytes32("Full"), bytes4("FULL"), bytes8("INV"));

        for (uint160 i = 1; i < 10; ++i) {
            address w = address(uint160(0xF00 + i));
            vm.prank(w); world.joinTribe(tid);
        }

        address overflow = address(uint160(0xF00 + 99));
        vm.prank(overflow);
        vm.expectRevert(AlphaLine.TribeFull.selector);
        world.joinTribe(tid);
    }

    // ─────────────────────────── yield engine ──────────────────────────────

    function test_computeYield_baseCase() public view {
        uint256 y = world.computeYield(
            100,
            AlphaLine.PlotTier.Bronze,
            1,
            false,
            false,
            0,
            false,
            false
        );
        assertEq(y, 100);
    }

    function test_computeYield_maxedOutFarmer() public view {
        uint256 y = world.computeYield(
            100,
            AlphaLine.PlotTier.Diamond,    // 3.0x
            4,                              // 2.0x
            true,                           // in tribe
            false,                          // not leader
            10,                             // 10 members
            true,                           // in alliance
            true                            // golden hour
        );
        // 100 * 3.0 * 2.0 * 1.10 * 1.05 * 1.20 = 831.6 -> 831
        assertEq(y, 831);
    }

    function test_computeYield_leaderScalesWithMembers() public view {
        uint256 leader10 = world.computeYield(100, AlphaLine.PlotTier.Bronze, 1, true, true, 10, false, false);
        uint256 leader2  = world.computeYield(100, AlphaLine.PlotTier.Bronze, 1, true, true,  2, false, false);
        // Leader bonus: 10_000 + 500 * (members - 1)
        // members=10 -> 14_500 (1.45x)   members=2 -> 10_500 (1.05x)
        assertEq(leader10, 145);
        assertEq(leader2,  105);
    }
}
