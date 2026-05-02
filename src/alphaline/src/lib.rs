// ─────────────────────────────────────────────────────────────────────────────
// AlphaLine — a multiplayer Solana prediction market protocol.
//
// World:    100 plots, four tiers, finite supply.
// Stake:    USDC locked into a per-plot vault PDA on claim.
// Markets:  P2P plot exchange + continuous order book for crops.
// Social:   Tribes (10 members, leader/member yield split) and Alliances
//           (5 members, flat yield bonus).
// Yield:    Multiplicative — upgrade × tribe × alliance × golden_hour.
//
// This file is the program entrypoint. Account state, instruction handlers,
// and the yield engine live in dedicated modules.
// ─────────────────────────────────────────────────────────────────────────────

use anchor_lang::prelude::*;

declare_id!("CrpLnd11111111111111111111111111111111111");

pub mod errors;
pub use errors::*;

#[program]
pub mod alphaline {
    use super::*;

    // Instructions are added incrementally as the protocol grows.
    // See programs/alphaline/src/instructions/* in upcoming commits.
}
