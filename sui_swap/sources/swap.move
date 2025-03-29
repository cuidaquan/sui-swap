#[allow(duplicate_alias)]
module sui_swap::swap {
    use sui::object::{Self};
    use sui::tx_context::TxContext;
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui_swap::liquidity_pool::{Self, LiquidityPool};
    use std::string::{Self, String};

    /// Swap event
    public struct SwapEvent has copy, drop {
        sender: address,
        pool_id: address,
        coin_in_type: String,
        coin_out_type: String,
        amount_in: u64,
        amount_out: u64,
    }

    /// Error codes
    const E_ZERO_AMOUNT: u64 = 0;
    const E_INSUFFICIENT_OUTPUT_AMOUNT: u64 = 1;
    const E_INSUFFICIENT_LIQUIDITY: u64 = 2;
    const E_INVALID_DEADLINE: u64 = 3;

    /// Swap token X to Y
    public fun swap_x_to_y<CoinTypeX, CoinTypeY>(
        pool: &mut LiquidityPool<CoinTypeX, CoinTypeY>,
        coin_x: Coin<CoinTypeX>,
        min_amount_out: u64,
        deadline: u64,
        ctx: &mut TxContext
    ): Coin<CoinTypeY> {
        // Check deadline
        assert!(tx_context::epoch(ctx) <= deadline, E_INVALID_DEADLINE);
        
        // Get input token amount
        let amount_in = coin::value(&coin_x);
        assert!(amount_in > 0, E_ZERO_AMOUNT);
        
        // Get reserves from the pool
        let (reserve_x, reserve_y) = liquidity_pool::get_reserves(pool);
        assert!(reserve_x > 0 && reserve_y > 0, E_INSUFFICIENT_LIQUIDITY);
        
        // Calculate output amount (considering fees), using u128 to avoid overflow
        let fee_percent = liquidity_pool::get_fee_percent(pool);
        
        let amount_in_u128 = (amount_in as u128);
        let reserve_x_u128 = (reserve_x as u128);
        let reserve_y_u128 = (reserve_y as u128);
        let fee_percent_u128 = (fee_percent as u128);
        
        let amount_in_with_fee_u128 = amount_in_u128 * (10000 - fee_percent_u128);
        let numerator_u128 = amount_in_with_fee_u128 * reserve_y_u128;
        let denominator_u128 = (reserve_x_u128 * 10000) + amount_in_with_fee_u128;
        let amount_out_u128 = numerator_u128 / denominator_u128;
        
        let amount_out = if (amount_out_u128 > (18446744073709551615 as u128)) {
            18446744073709551615 // u64::MAX
        } else {
            (amount_out_u128 as u64)
        };
        
        // Check if output amount meets minimum requirement
        assert!(amount_out >= min_amount_out, E_INSUFFICIENT_OUTPUT_AMOUNT);
        
        // Execute swap
        let coin_y = liquidity_pool::swap_x_to_y(pool, coin_x, amount_out, ctx);
        
        // Emit swap event
        event::emit(SwapEvent {
            sender: tx_context::sender(ctx),
            pool_id: object::uid_to_address(liquidity_pool::get_pool_id(pool)),
            coin_in_type: get_coin_name<CoinTypeX>(),
            coin_out_type: get_coin_name<CoinTypeY>(),
            amount_in,
            amount_out,
        });
        
        coin_y
    }

    /// Swap token Y to X
    public fun swap_y_to_x<CoinTypeX, CoinTypeY>(
        pool: &mut LiquidityPool<CoinTypeX, CoinTypeY>,
        coin_y: Coin<CoinTypeY>,
        min_amount_out: u64,
        deadline: u64,
        ctx: &mut TxContext
    ): Coin<CoinTypeX> {
        // Check deadline
        assert!(tx_context::epoch(ctx) <= deadline, E_INVALID_DEADLINE);
        
        // Get input token amount
        let amount_in = coin::value(&coin_y);
        assert!(amount_in > 0, E_ZERO_AMOUNT);
        
        // Get reserves from the pool
        let (reserve_x, reserve_y) = liquidity_pool::get_reserves(pool);
        assert!(reserve_x > 0 && reserve_y > 0, E_INSUFFICIENT_LIQUIDITY);
        
        // Calculate output amount (considering fees), using u128 to avoid overflow
        let fee_percent = liquidity_pool::get_fee_percent(pool);
        
        let amount_in_u128 = (amount_in as u128);
        let reserve_x_u128 = (reserve_x as u128);
        let reserve_y_u128 = (reserve_y as u128);
        let fee_percent_u128 = (fee_percent as u128);
        
        let amount_in_with_fee_u128 = amount_in_u128 * (10000 - fee_percent_u128);
        let numerator_u128 = amount_in_with_fee_u128 * reserve_x_u128;
        let denominator_u128 = (reserve_y_u128 * 10000) + amount_in_with_fee_u128;
        let amount_out_u128 = numerator_u128 / denominator_u128;
        
        let amount_out = if (amount_out_u128 > (18446744073709551615 as u128)) {
            18446744073709551615 // u64::MAX
        } else {
            (amount_out_u128 as u64)
        };
        
        // Check if output amount meets minimum requirement
        assert!(amount_out >= min_amount_out, E_INSUFFICIENT_OUTPUT_AMOUNT);
        
        // Execute swap
        let coin_x = liquidity_pool::swap_y_to_x(pool, coin_y, amount_out, ctx);
        
        // Emit swap event
        event::emit(SwapEvent {
            sender: tx_context::sender(ctx),
            pool_id: object::uid_to_address(liquidity_pool::get_pool_id(pool)),
            coin_in_type: get_coin_name<CoinTypeY>(),
            coin_out_type: get_coin_name<CoinTypeX>(),
            amount_in,
            amount_out,
        });
        
        coin_x
    }

    /// Get coin name (helper function)
    fun get_coin_name<CoinType>(): String {
        let type_name = std::type_name::get<CoinType>();
        string::utf8(std::ascii::into_bytes(std::type_name::into_string(type_name)))
    }
}