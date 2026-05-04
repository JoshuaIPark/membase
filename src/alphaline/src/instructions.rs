use anchor_lang::prelude::*;
use anchor_spl::token::{Token, TokenAccount, Mint, Transfer, transfer};

use crate::state::*;
use crate::errors::ErrorCode;

// ═════════════════════════════════════════════════════════════════════════════
//                                  PLOTS
// ═════════════════════════════════════════════════════════════════════════════

#[derive(Accounts)]
#[instruction(plot_id: u8, tier: PlotTier)]
pub struct ClaimPlot<'info> {
    #[account(
        mut,
        seeds = [b"plot", &[plot_id]],
        bump  = plot.bump,
    )]
    pub plot: Account<'info, Plot>,

    #[account(
        mut,
        seeds = [b"player", player_signer.key().as_ref()],
        bump  = player.bump,
    )]
    pub player: Account<'info, Player>,

    /// Plot vault (per-plot PDA token account holding the locked stake).
    #[account(
        mut,
        seeds = [b"vault", &[plot_id]],
        bump,
    )]
    pub plot_vault: Account<'info, TokenAccount>,

    /// Buyer's USDC ATA.
    #[account(mut, token::mint = usdc_mint)]
    pub player_token: Account<'info, TokenAccount>,

    pub usdc_mint:     Account<'info, Mint>,
    #[account(mut)]
    pub player_signer: Signer<'info>,
    pub token_program: Program<'info, Token>,
}

pub fn claim_plot(ctx: Context<ClaimPlot>, _plot_id: u8, tier: PlotTier) -> Result<()> {
    let plot   = &mut ctx.accounts.plot;
    let player = &mut ctx.accounts.player;

    require!(plot.owner == Pubkey::default(),         ErrorCode::AlreadyClaimed);
    require!(player.plot_count < MAX_PLOTS_PER_WALLET, ErrorCode::TooManyPlots);

    let cost = tier.claim_cost();
    let cpi = CpiContext::new(
        ctx.accounts.token_program.to_account_info(),
        Transfer {
            from:      ctx.accounts.player_token.to_account_info(),
            to:        ctx.accounts.plot_vault.to_account_info(),
            authority: ctx.accounts.player_signer.to_account_info(),
        },
    );
    transfer(cpi, cost)?;

    plot.owner         = ctx.accounts.player_signer.key();
    plot.tier          = tier;
    plot.locked_amount = cost;
    plot.claimed_at    = Clock::get()?.unix_timestamp;
    plot.upgrade_level = 1;
    plot.last_harvest  = 0;

    player.plot_count = player.plot_count.saturating_add(1);

    emit!(PlotClaimed {
        plot:   plot.key(),
        owner:  plot.owner,
        tier,
        stake:  cost,
    });
    Ok(())
}

#[derive(Accounts)]
pub struct AbandonPlot<'info> {
    #[account(
        mut,
        seeds = [b"plot", &[plot.id]],
        bump  = plot.bump,
        constraint = plot.owner == player_signer.key() @ ErrorCode::NotOwner,
    )]
    pub plot: Account<'info, Plot>,

    #[account(mut)]
    pub player: Account<'info, Player>,

    /// Per-plot vault PDA — drained on abandon.
    #[account(mut)]
    pub plot_vault:     Account<'info, TokenAccount>,
    #[account(mut)]
    pub burn_vault:     Account<'info, TokenAccount>,
    #[account(mut)]
    pub treasury_vault: Account<'info, TokenAccount>,

    /// CHECK: program PDA authority for the plot vault.
    pub vault_authority: AccountInfo<'info>,

    pub player_signer: Signer<'info>,
    pub token_program: Program<'info, Token>,
}

pub fn abandon_plot(ctx: Context<AbandonPlot>) -> Result<()> {
    let plot   = &mut ctx.accounts.plot;
    let player = &mut ctx.accounts.player;

    let stake    = plot.locked_amount;
    let burn     = stake.saturating_mul(ABANDON_BURN_BPS)     / 10_000;
    let treasury = stake.saturating_mul(ABANDON_TREASURY_BPS) / 10_000;

    let plot_id = plot.id;
    let bump    = plot.bump;
    let signer  = &[&[b"vault", &[plot_id], &[bump]][..]];

    transfer(
        CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from:      ctx.accounts.plot_vault.to_account_info(),
                to:        ctx.accounts.burn_vault.to_account_info(),
                authority: ctx.accounts.vault_authority.clone(),
            },
            signer,
        ),
        burn,
    )?;

    transfer(
        CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from:      ctx.accounts.plot_vault.to_account_info(),
                to:        ctx.accounts.treasury_vault.to_account_info(),
                authority: ctx.accounts.vault_authority.clone(),
            },
            signer,
        ),
        treasury,
    )?;

    plot.owner         = Pubkey::default();
    plot.locked_amount = 0;
    plot.claimed_at    = 0;
    plot.upgrade_level = 1;

    player.plot_count = player.plot_count.saturating_sub(1);

    emit!(PlotAbandoned { plot: plot.key(), forfeit: stake });
    Ok(())
}

#[derive(Accounts)]
pub struct UpgradePlot<'info> {
    #[account(
        mut,
        constraint = plot.owner == player_signer.key() @ ErrorCode::NotOwner,
    )]
    pub plot: Account<'info, Plot>,

    #[account(mut, token::mint = usdc_mint)]
    pub player_token:   Account<'info, TokenAccount>,
    #[account(mut)]
    pub treasury_vault: Account<'info, TokenAccount>,

    pub usdc_mint:     Account<'info, Mint>,
    pub player_signer: Signer<'info>,
    pub token_program: Program<'info, Token>,
}

pub fn upgrade_plot(ctx: Context<UpgradePlot>) -> Result<()> {
    let plot = &mut ctx.accounts.plot;
    require!(plot.upgrade_level < 4, ErrorCode::UpgradeMaxed);

    let next = plot.upgrade_level + 1;
    let cost = upgrade_cost(next);

    let cpi = CpiContext::new(
        ctx.accounts.token_program.to_account_info(),
        Transfer {
            from:      ctx.accounts.player_token.to_account_info(),
            to:        ctx.accounts.treasury_vault.to_account_info(),
            authority: ctx.accounts.player_signer.to_account_info(),
        },
    );
    transfer(cpi, cost)?;

    plot.upgrade_level = next;
    Ok(())
}

// ═════════════════════════════════════════════════════════════════════════════
//                              PLOT EXCHANGE
// ═════════════════════════════════════════════════════════════════════════════

#[derive(Accounts)]
pub struct ListPlot<'info> {
    #[account(
        mut,
        constraint = plot.owner == seller.key() @ ErrorCode::NotOwner,
    )]
    pub plot: Account<'info, Plot>,

    #[account(
        init_if_needed,
        payer = seller,
        space = 8 + 32 + 32 + 33 + 8 + 1 + 8 + 1,
        seeds = [b"offer", plot.key().as_ref()],
        bump,
    )]
    pub offer: Account<'info, PlotOffer>,

    #[account(mut)]
    pub seller:         Signer<'info>,
    pub system_program: Program<'info, System>,
}

pub fn list_plot(
    ctx: Context<ListPlot>,
    price: u64,
    target_buyer: Option<Pubkey>,
) -> Result<()> {
    let offer = &mut ctx.accounts.offer;
    require!(price > 0, ErrorCode::InvalidOrder);

    offer.plot       = ctx.accounts.plot.key();
    offer.seller     = ctx.accounts.seller.key();
    offer.buyer      = target_buyer;
    offer.price      = price;
    offer.status     = OfferStatus::Open;
    offer.created_at = Clock::get()?.unix_timestamp;
    Ok(())
}

#[derive(Accounts)]
pub struct AcceptPlotOffer<'info> {
    #[account(
        mut,
        seeds = [b"offer", plot.key().as_ref()],
        bump  = offer.bump,
    )]
    pub offer: Account<'info, PlotOffer>,

    #[account(mut)]
    pub plot: Account<'info, Plot>,

    #[account(mut, token::mint = usdc_mint)]
    pub buyer_token:    Account<'info, TokenAccount>,
    #[account(mut, token::mint = usdc_mint)]
    pub seller_token:   Account<'info, TokenAccount>,
    #[account(mut, token::mint = usdc_mint)]
    pub treasury_vault: Account<'info, TokenAccount>,

    pub usdc_mint:     Account<'info, Mint>,
    #[account(mut)]
    pub buyer:         Signer<'info>,
    pub token_program: Program<'info, Token>,
}

pub fn accept_plot_offer(ctx: Context<AcceptPlotOffer>) -> Result<()> {
    let offer    = &mut ctx.accounts.offer;
    let plot     = &mut ctx.accounts.plot;
    let buyer_pk = ctx.accounts.buyer.key();

    // Optimistic concurrency: every condition required atomically.
    require!(offer.status == OfferStatus::Open,        ErrorCode::OfferClosed);
    require!(plot.owner   == offer.seller,             ErrorCode::SellerNoLongerOwns);
    require!(offer.seller != buyer_pk,                 ErrorCode::SelfTrade);
    require!(
        offer.buyer.map_or(true, |b| b == buyer_pk),
        ErrorCode::OfferNotForYou,
    );

    let fee = offer.price.saturating_mul(FEE_BPS) / 10_000;
    let net = offer.price.saturating_sub(fee);

    // Buyer USDC → seller (net) + treasury (fee).
    transfer(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from:      ctx.accounts.buyer_token.to_account_info(),
                to:        ctx.accounts.seller_token.to_account_info(),
                authority: ctx.accounts.buyer.to_account_info(),
            },
        ),
        net,
    )?;
    transfer(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from:      ctx.accounts.buyer_token.to_account_info(),
                to:        ctx.accounts.treasury_vault.to_account_info(),
                authority: ctx.accounts.buyer.to_account_info(),
            },
        ),
        fee,
    )?;

    plot.owner      = buyer_pk;
    plot.claimed_at = Clock::get()?.unix_timestamp;

    offer.status = OfferStatus::Accepted;
    offer.buyer  = Some(buyer_pk);

    emit!(PlotTraded {
        plot:   plot.key(),
        seller: offer.seller,
        buyer:  buyer_pk,
        price:  offer.price,
    });
    Ok(())
}

// ═════════════════════════════════════════════════════════════════════════════
//                          MARKETPLACE — ORDER BOOK
// ═════════════════════════════════════════════════════════════════════════════

#[derive(Accounts)]
#[instruction(args: PlaceOrderArgs)]
pub struct PlaceOrder<'info> {
    #[account(
        init,
        payer = maker,
        space = 8 + 8 + 32 + 1 + 1 + 8 + 8 + 8 + 1 + 8 + 1,
        seeds = [b"order", &args.id.to_le_bytes()],
        bump,
    )]
    pub order: Account<'info, Order>,

    #[account(mut)]
    pub maker_token:  Account<'info, TokenAccount>,
    #[account(mut)]
    pub escrow:       Account<'info, TokenAccount>,

    #[account(mut)]
    pub maker:          Signer<'info>,
    pub token_program:  Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct PlaceOrderArgs {
    pub id:       u64,
    pub item:     ItemType,
    pub side:     Side,
    pub quantity: u64,
    pub price:    u64,
}

pub fn place_order(ctx: Context<PlaceOrder>, args: PlaceOrderArgs) -> Result<()> {
    require!(args.quantity > 0 && args.price > 0, ErrorCode::InvalidOrder);

    let order = &mut ctx.accounts.order;
    order.id         = args.id;
    order.maker      = ctx.accounts.maker.key();
    order.item       = args.item;
    order.side       = args.side;
    order.quantity   = args.quantity;
    order.remaining  = args.quantity;
    order.price      = args.price;
    order.status     = OrderStatus::Open;
    order.created_at = Clock::get()?.unix_timestamp;

    let lock_amount = match args.side {
        Side::Bid => args.quantity.saturating_mul(args.price),  // USDC
        Side::Ask => args.quantity,                              // items
    };

    let cpi = CpiContext::new(
        ctx.accounts.token_program.to_account_info(),
        Transfer {
            from:      ctx.accounts.maker_token.to_account_info(),
            to:        ctx.accounts.escrow.to_account_info(),
            authority: ctx.accounts.maker.to_account_info(),
        },
    );
    transfer(cpi, lock_amount)?;

    Ok(())
}

/// Match the top of the book for `item`. Walks asks ascending and bids
/// descending; fills at ask price; stops when the book crosses or one side is
/// exhausted. The patient seller wins ties. Self-matching is prevented at the
/// pair level.
pub fn match_book(item: ItemType, asks: &mut [Order], bids: &mut [Order]) -> Result<()> {
    for ask in asks.iter_mut().filter(|o| o.item == item && o.status == OrderStatus::Open) {
        for bid in bids.iter_mut().filter(|o| o.item == item && o.status == OrderStatus::Open) {
            if bid.price < ask.price        { break;    }
            if bid.maker == ask.maker       { continue; }   // self-match guard

            let qty   = ask.remaining.min(bid.remaining);
            let price = ask.price;
            let gross = qty.saturating_mul(price);
            let fee   = gross.saturating_mul(FEE_BPS) / 10_000;
            let net   = gross.saturating_sub(fee);

            // Settle: bid escrow -> ask maker (net) + treasury (fee)
            // Settle: ask escrow -> bid maker (qty items)
            // (CPI calls elided in this helper — performed by the caller.)

            ask.remaining = ask.remaining.saturating_sub(qty);
            bid.remaining = bid.remaining.saturating_sub(qty);
            if ask.remaining == 0 { ask.status = OrderStatus::Filled; }
            if bid.remaining == 0 { bid.status = OrderStatus::Filled; }

            emit!(OrderFilled {
                ask: ask.id,
                bid: bid.id,
                qty,
                price,
                fee,
                net,
            });

            if ask.remaining == 0 { break; }
        }
    }
    Ok(())
}

// ═════════════════════════════════════════════════════════════════════════════
//                                 SOCIAL
// ═════════════════════════════════════════════════════════════════════════════

#[derive(Accounts)]
pub struct CreateTribe<'info> {
    #[account(init, payer = leader, space = 8 + 8 + 32 + 4 + 32 + 32 + 1 + 8 + 8 + 1)]
    pub tribe: Account<'info, Tribe>,

    #[account(mut)]
    pub leader:         Signer<'info>,
    pub system_program: Program<'info, System>,
}

pub fn create_tribe(
    ctx: Context<CreateTribe>,
    name: [u8; 32],
    tag:  [u8; 4],
    home_plot: Pubkey,
    invite_code: [u8; 8],
) -> Result<()> {
    let tribe = &mut ctx.accounts.tribe;
    tribe.id           = Clock::get()?.unix_timestamp as u64;
    tribe.name         = name;
    tribe.tag          = tag;
    tribe.leader       = ctx.accounts.leader.key();
    tribe.home_plot    = home_plot;
    tribe.member_count = 1;
    tribe.invite_code  = invite_code;
    tribe.created_at   = Clock::get()?.unix_timestamp;
    Ok(())
}

#[derive(Accounts)]
pub struct JoinTribe<'info> {
    #[account(mut)]
    pub tribe: Account<'info, Tribe>,

    #[account(
        init,
        payer = wallet,
        space = 8 + 32 + 32 + 8 + 1 + 1,
        seeds = [b"tribe_member", tribe.key().as_ref(), wallet.key().as_ref()],
        bump,
    )]
    pub member: Account<'info, TribeMember>,

    #[account(mut)]
    pub wallet:         Signer<'info>,
    pub system_program: Program<'info, System>,
}

pub fn join_tribe(ctx: Context<JoinTribe>) -> Result<()> {
    let tribe  = &mut ctx.accounts.tribe;
    let member = &mut ctx.accounts.member;

    require!(tribe.member_count < TRIBE_MAX_MEMBERS, ErrorCode::TribeFull);

    member.tribe     = tribe.key();
    member.wallet    = ctx.accounts.wallet.key();
    member.joined_at = Clock::get()?.unix_timestamp;
    member.is_leader = false;

    tribe.member_count = tribe.member_count.saturating_add(1);
    Ok(())
}

#[derive(Accounts)]
pub struct CreateAlliance<'info> {
    #[account(init, payer = founder, space = 8 + 8 + 32 + 1 + 8 + 1)]
    pub alliance: Account<'info, Alliance>,

    #[account(mut)]
    pub founder:        Signer<'info>,
    pub system_program: Program<'info, System>,
}

pub fn create_alliance(ctx: Context<CreateAlliance>, name: [u8; 32]) -> Result<()> {
    let a = &mut ctx.accounts.alliance;
    a.id           = Clock::get()?.unix_timestamp as u64;
    a.name         = name;
    a.member_count = 1;
    a.created_at   = Clock::get()?.unix_timestamp;
    Ok(())
}

#[derive(Accounts)]
pub struct JoinAlliance<'info> {
    #[account(mut)]
    pub alliance: Account<'info, Alliance>,

    #[account(
        init,
        payer = wallet,
        space = 8 + 32 + 32 + 8 + 1,
        seeds = [b"alliance_member", alliance.key().as_ref(), wallet.key().as_ref()],
        bump,
    )]
    pub member: Account<'info, AllianceMember>,

    #[account(mut)]
    pub wallet:         Signer<'info>,
    pub system_program: Program<'info, System>,
}

pub fn join_alliance(ctx: Context<JoinAlliance>) -> Result<()> {
    let a = &mut ctx.accounts.alliance;
    let m = &mut ctx.accounts.member;

    require!(a.member_count < ALLIANCE_MAX_MEMBERS, ErrorCode::AllianceFull);

    m.alliance  = a.key();
    m.wallet    = ctx.accounts.wallet.key();
    m.joined_at = Clock::get()?.unix_timestamp;

    a.member_count = a.member_count.saturating_add(1);
    Ok(())
}

// ═════════════════════════════════════════════════════════════════════════════
//                                 HARVEST
// ═════════════════════════════════════════════════════════════════════════════

#[derive(Accounts)]
pub struct Harvest<'info> {
    #[account(
        mut,
        constraint = plot.owner == player_signer.key() @ ErrorCode::NotOwner,
    )]
    pub plot:   Account<'info, Plot>,
    #[account(mut)]
    pub player: Account<'info, Player>,

    pub player_signer: Signer<'info>,
    pub token_program: Program<'info, Token>,
}

pub fn harvest(
    ctx:               Context<Harvest>,
    base_amount:       u64,
    in_tribe:          bool,
    is_tribe_leader:   bool,
    tribe_members:     u8,
    in_alliance:       bool,
) -> Result<()> {
    let plot   = &mut ctx.accounts.plot;
    let player = &ctx.accounts.player;
    let now    = Clock::get()?.unix_timestamp;

    require!(
        now.saturating_sub(plot.last_harvest) >= HARVEST_COOLDOWN_S,
        ErrorCode::HarvestCooldown,
    );

    let golden = is_golden_hour(now);
    let amount = compute_yield(
        base_amount,
        plot.tier,
        plot.upgrade_level,
        in_tribe,
        is_tribe_leader,
        tribe_members,
        in_alliance,
        golden,
    );

    plot.last_harvest = now;

    emit!(Harvested {
        plot:   plot.key(),
        owner:  player.wallet,
        amount,
        golden,
    });
    Ok(())
}

// ═════════════════════════════════════════════════════════════════════════════
//                                 EVENTS
// ═════════════════════════════════════════════════════════════════════════════

#[event]
pub struct PlotClaimed { pub plot: Pubkey, pub owner: Pubkey, pub tier: PlotTier, pub stake: u64 }
#[event]
pub struct PlotAbandoned { pub plot: Pubkey, pub forfeit: u64 }
#[event]
pub struct PlotTraded { pub plot: Pubkey, pub seller: Pubkey, pub buyer: Pubkey, pub price: u64 }
#[event]
pub struct OrderFilled { pub ask: u64, pub bid: u64, pub qty: u64, pub price: u64, pub fee: u64, pub net: u64 }
#[event]
pub struct Harvested { pub plot: Pubkey, pub owner: Pubkey, pub amount: u64, pub golden: bool }
