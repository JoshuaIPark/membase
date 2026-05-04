// ─────────────────────────────────────────────────────────────────────────────
// AlphaLine — a multiplayer Solana prediction market protocol.
//
// World:    100 plots, four tiers, finite supply.
// Stake:    USDC locked into a per-plot vault PDA on claim.
// Markets:  P2P plot exchange + continuous order book for crops.
// Social:   Tribes (10 members, leader/member yield split) and Alliances
//           (5 members, flat yield bonus).
// Yield:    Multiplicative — tier × upgrade × tribe × alliance × golden_hour.
// ─────────────────────────────────────────────────────────────────────────────

use anchor_lang::prelude::*;

declare_id!("CrpLnd11111111111111111111111111111111111");

pub mod errors;
pub mod state;
pub mod instructions;

pub use errors::*;
pub use state::*;
pub use instructions::*;

#[program]
pub mod alphaline {
    use super::*;

    // ────────── Plots ──────────
    pub fn claim_plot(ctx: Context<ClaimPlot>, plot_id: u8, tier: PlotTier) -> Result<()> {
        instructions::claim_plot(ctx, plot_id, tier)
    }
    pub fn abandon_plot(ctx: Context<AbandonPlot>) -> Result<()> {
        instructions::abandon_plot(ctx)
    }
    pub fn upgrade_plot(ctx: Context<UpgradePlot>) -> Result<()> {
        instructions::upgrade_plot(ctx)
    }

    // ────────── Plot exchange ──────────
    pub fn list_plot(ctx: Context<ListPlot>, price: u64, target_buyer: Option<Pubkey>) -> Result<()> {
        instructions::list_plot(ctx, price, target_buyer)
    }
    pub fn accept_plot_offer(ctx: Context<AcceptPlotOffer>) -> Result<()> {
        instructions::accept_plot_offer(ctx)
    }

    // ────────── Order book ──────────
    pub fn place_order(ctx: Context<PlaceOrder>, args: PlaceOrderArgs) -> Result<()> {
        instructions::place_order(ctx, args)
    }

    // ────────── Social ──────────
    pub fn create_tribe(
        ctx: Context<CreateTribe>,
        name: [u8; 32],
        tag:  [u8; 4],
        home_plot: Pubkey,
        invite_code: [u8; 8],
    ) -> Result<()> {
        instructions::create_tribe(ctx, name, tag, home_plot, invite_code)
    }
    pub fn join_tribe(ctx: Context<JoinTribe>) -> Result<()> {
        instructions::join_tribe(ctx)
    }
    pub fn create_alliance(ctx: Context<CreateAlliance>, name: [u8; 32]) -> Result<()> {
        instructions::create_alliance(ctx, name)
    }
    pub fn join_alliance(ctx: Context<JoinAlliance>) -> Result<()> {
        instructions::join_alliance(ctx)
    }

    // ────────── Harvest ──────────
    pub fn harvest(
        ctx:             Context<Harvest>,
        base_amount:     u64,
        in_tribe:        bool,
        is_tribe_leader: bool,
        tribe_members:   u8,
        in_alliance:     bool,
    ) -> Result<()> {
        instructions::harvest(ctx, base_amount, in_tribe, is_tribe_leader, tribe_members, in_alliance)
    }
}
