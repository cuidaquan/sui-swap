/*
/// Module: sui_swap
module sui_swap::sui_swap;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions

#[allow(duplicate_alias)]
module sui_swap::sui_swap {
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::Coin;
    use sui_swap::factory::{Self, Factory};
    use sui_swap::liquidity_pool::{Self, LiquidityPool, LPCoin};
    use sui_swap::swap;

    /// Default fee rate (0.3%)
    const DEFAULT_FEE_PERCENT: u64 = 30;

    /// One-time witness type for initialization
    public struct SUI_SWAP has drop {}

    /// Initialization function
    fun init(_witness: SUI_SWAP, ctx: &mut TxContext) {
        // Create factory
        factory::create_factory(DEFAULT_FEE_PERCENT, ctx);
    }

    /// Create liquidity pool
    public entry fun create_pool<CoinTypeX, CoinTypeY>(
        factory: &mut Factory,
        coin_x: Coin<CoinTypeX>,
        coin_y: Coin<CoinTypeY>,
        fee_percent: u64,
        ctx: &mut TxContext
    ) {
        factory::create_pool(factory, coin_x, coin_y, fee_percent, ctx);
    }

    /// Create liquidity pool with default fee rate
    public entry fun create_pool_with_default_fee<CoinTypeX, CoinTypeY>(
        factory: &mut Factory,
        coin_x: Coin<CoinTypeX>,
        coin_y: Coin<CoinTypeY>,
        ctx: &mut TxContext
    ) {
        factory::create_pool_with_default_fee(factory, coin_x, coin_y, ctx);
    }

    /// Add liquidity
    public entry fun add_liquidity<CoinTypeX, CoinTypeY>(
        pool: &mut LiquidityPool<CoinTypeX, CoinTypeY>,
        coin_x: Coin<CoinTypeX>,
        coin_y: Coin<CoinTypeY>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let (lp_coin, remaining_x, remaining_y) = liquidity_pool::add_liquidity(pool, coin_x, coin_y, ctx);
        
        // Transfer LP tokens and remaining coins to user
        transfer::public_transfer(lp_coin, sender);
        transfer::public_transfer(remaining_x, sender);
        transfer::public_transfer(remaining_y, sender);
    }

    /// Remove liquidity
    public entry fun remove_liquidity<CoinTypeX, CoinTypeY>(
        pool: &mut LiquidityPool<CoinTypeX, CoinTypeY>,
        lp_coin: LPCoin<CoinTypeX, CoinTypeY>,
        ctx: &mut TxContext
    ) {
        let (coin_x, coin_y) = liquidity_pool::remove_liquidity(pool, lp_coin, ctx);
        transfer::public_transfer(coin_x, tx_context::sender(ctx));
        transfer::public_transfer(coin_y, tx_context::sender(ctx));
    }

    /// Swap X to Y token
    public entry fun swap_x_to_y<CoinTypeX, CoinTypeY>(
        pool: &mut LiquidityPool<CoinTypeX, CoinTypeY>,
        coin_x: Coin<CoinTypeX>,
        min_amount_out: u64,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        let coin_y = swap::swap_x_to_y(pool, coin_x, min_amount_out, deadline, ctx);
        transfer::public_transfer(coin_y, tx_context::sender(ctx));
    }

    /// Swap Y to X token
    public entry fun swap_y_to_x<CoinTypeX, CoinTypeY>(
        pool: &mut LiquidityPool<CoinTypeX, CoinTypeY>,
        coin_y: Coin<CoinTypeY>,
        min_amount_out: u64,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        let coin_x = swap::swap_y_to_x(pool, coin_y, min_amount_out, deadline, ctx);
        transfer::public_transfer(coin_x, tx_context::sender(ctx));
    }

    /// Update factory default fee rate
    public entry fun update_default_fee_percent(
        factory: &mut Factory,
        new_fee_percent: u64,
        ctx: &mut TxContext
    ) {
        factory::update_default_fee_percent(factory, new_fee_percent, ctx);
    }

    /// Transfer factory ownership
    public entry fun transfer_factory_ownership(
        factory: &mut Factory,
        new_owner: address,
        ctx: &mut TxContext
    ) {
        factory::transfer_ownership(factory, new_owner, ctx);
    }
}


