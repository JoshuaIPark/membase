use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("Plot is already claimed.")]
    AlreadyClaimed,
    #[msg("Plot is not claimed yet.")]
    NotClaimed,
    #[msg("You do not own this plot.")]
    NotOwner,
    #[msg("Wallet has reached the 5-plot cap.")]
    TooManyPlots,
    #[msg("Insufficient USDC to claim this tier.")]
    InsufficientStake,
    #[msg("Plot upgrade level is already maxed.")]
    UpgradeMaxed,
    #[msg("Offer is no longer open.")]
    OfferClosed,
    #[msg("Seller no longer owns this plot.")]
    SellerNoLongerOwns,
    #[msg("Cannot accept your own offer.")]
    SelfTrade,
    #[msg("This offer is targeted at another wallet.")]
    OfferNotForYou,
    #[msg("Insufficient inventory to place ask.")]
    InsufficientInventory,
    #[msg("Tribe is full.")]
    TribeFull,
    #[msg("Alliance is full.")]
    AllianceFull,
    #[msg("Already a member.")]
    AlreadyMember,
    #[msg("Not a member.")]
    NotMember,
    #[msg("Only the leader may perform this action.")]
    NotLeader,
    #[msg("Harvest cooldown not elapsed.")]
    HarvestCooldown,
    #[msg("Order book in invalid state.")]
    InvalidOrder,
    #[msg("Math overflow.")]
    MathOverflow,
}
