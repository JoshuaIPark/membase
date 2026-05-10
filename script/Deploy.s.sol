// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console}  from "forge-std/Script.sol";
import {AlphaLine}       from "../contracts/AlphaLine.sol";
import {IERC20}           from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Deploys AlphaLine to Base mainnet or Base Sepolia.
///
/// Usage:
///   forge script script/Deploy.s.sol --rpc-url base         --broadcast --verify
///   forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast --verify
contract Deploy is Script {
    // Circle-issued native USDC on Base mainnet.
    address constant USDC_BASE         = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    // USDC on Base Sepolia (Circle test deployment).
    address constant USDC_BASE_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    function run() external returns (AlphaLine world) {
        address usdc     = _usdcForChain();
        address treasury = vm.envAddress("TREASURY");

        vm.startBroadcast();
        world = new AlphaLine(IERC20(usdc), treasury);
        vm.stopBroadcast();

        console.log("AlphaLine deployed at:", address(world));
        console.log("  USDC:    ", usdc);
        console.log("  Treasury:", treasury);
    }

    function _usdcForChain() internal view returns (address) {
        if (block.chainid == 8453)  return USDC_BASE;
        if (block.chainid == 84532) return USDC_BASE_SEPOLIA;
        revert("Unsupported chain — only Base mainnet (8453) and Base Sepolia (84532)");
    }
}
