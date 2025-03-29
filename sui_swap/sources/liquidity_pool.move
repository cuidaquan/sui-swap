#[allow(duplicate_alias)]
module sui_swap::liquidity_pool {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::balance::{Self, Balance};
    use std::string::{Self, String};
    use std::u128;

    /// Liquidity pool structure
    public struct LiquidityPool<phantom CoinTypeX, phantom CoinTypeY> has key, store {
        id: UID,
        reserve_x: Balance<CoinTypeX>,
        reserve_y: Balance<CoinTypeY>,
        lp_supply: u64,
        fee_percent: u64, // expressed in basis points, e.g., 30 means 0.3%
        coin_x_type: String,
        coin_y_type: String,
    }

    /// LP token structure
    public struct LPCoin<phantom CoinTypeX, phantom CoinTypeY> has key, store {
        id: UID,
        amount: u64,
    }

    /// Pool creation event
    public struct PoolCreatedEvent has copy, drop {
        pool_id: address,
        coin_x_type: String,
        coin_y_type: String,
    }

    /// Add liquidity event
    public struct LiquidityAddedEvent has copy, drop {
        provider: address,
        pool_id: address,
        amount_x: u64,
        amount_y: u64,
        lp_tokens: u64,
    }

    /// Remove liquidity event
    public struct LiquidityRemovedEvent has copy, drop {
        provider: address,
        pool_id: address,
        amount_x: u64,
        amount_y: u64,
        lp_tokens: u64,
    }

    /// Error codes
    const E_ZERO_AMOUNT: u64 = 0;
    const E_INSUFFICIENT_LIQUIDITY: u64 = 1;
    const E_INSUFFICIENT_X_AMOUNT: u64 = 2;
    const E_INSUFFICIENT_Y_AMOUNT: u64 = 3;
    const E_INVALID_FEE_PERCENT: u64 = 4;
    const E_K_VALUE_INVARIANT: u64 = 5;
    const E_SAME_COIN_TYPE: u64 = 6;

    /// Create a new liquidity pool
    public fun create_pool<CoinTypeX, CoinTypeY>(
        coin_x: Coin<CoinTypeX>,
        coin_y: Coin<CoinTypeY>,
        fee_percent: u64,
        ctx: &mut TxContext
    ): LiquidityPool<CoinTypeX, CoinTypeY> {
        // Validate fee rate is within reasonable range (0-5%)
        assert!(fee_percent <= 500, E_INVALID_FEE_PERCENT);
        
        // Ensure token types are different
        assert!(!is_same_type<CoinTypeX, CoinTypeY>(), E_SAME_COIN_TYPE);
        
        // Get token amounts
        let amount_x = coin::value(&coin_x);
        let amount_y = coin::value(&coin_y);
        
        // Ensure amounts are not zero
        assert!(amount_x > 0 && amount_y > 0, E_ZERO_AMOUNT);
        
        // Create liquidity pool
        let pool_id = object::new(ctx);
        let pool_address = object::uid_to_address(&pool_id);
        
        // Use u128 for large number calculations
        let amount_x_u128 = (amount_x as u128);
        let amount_y_u128 = (amount_y as u128);
        let product = amount_x_u128 * amount_y_u128;
        let sqrt_product = u128::sqrt(product);
        // Convert back to u64, ensure no overflow
        let lp_supply = if (sqrt_product > (18446744073709551615 as u128)) {
            18446744073709551615 // u64::MAX
        } else {
            (sqrt_product as u64)
        };
        
        // Create liquidity pool object
        let pool = LiquidityPool<CoinTypeX, CoinTypeY> {
            id: pool_id,
            reserve_x: coin::into_balance(coin_x),
            reserve_y: coin::into_balance(coin_y),
            lp_supply,
            fee_percent,
            coin_x_type: get_coin_name<CoinTypeX>(),
            coin_y_type: get_coin_name<CoinTypeY>(),
        };
        
        // Emit pool creation event
        event::emit(PoolCreatedEvent {
            pool_id: pool_address,
            coin_x_type: get_coin_name<CoinTypeX>(),
            coin_y_type: get_coin_name<CoinTypeY>(),
        });
        
        pool
    }

    /// Add liquidity
    public fun add_liquidity<CoinTypeX, CoinTypeY>(
        pool: &mut LiquidityPool<CoinTypeX, CoinTypeY>,
        mut coin_x: Coin<CoinTypeX>,
        mut coin_y: Coin<CoinTypeY>,
        ctx: &mut TxContext
    ): (LPCoin<CoinTypeX, CoinTypeY>, Coin<CoinTypeX>, Coin<CoinTypeY>) {
        let amount_x = coin::value(&coin_x);
        let amount_y = coin::value(&coin_y);
        
        // Ensure amounts are not zero
        assert!(amount_x > 0 && amount_y > 0, E_ZERO_AMOUNT);
        
        // Get current pool state
        let reserve_x = balance::value(&pool.reserve_x);
        let reserve_y = balance::value(&pool.reserve_y);
        
        // Ensure reserve_x and reserve_y are not zero
        assert!(reserve_x > 0 && reserve_y > 0, E_INSUFFICIENT_LIQUIDITY);
        
        let (actual_x, actual_y, lp_amount);
        
        // Use u128 for calculations to avoid overflow
        let reserve_x_u128 = (reserve_x as u128);
        let reserve_y_u128 = (reserve_y as u128);
        let amount_x_u128 = (amount_x as u128);
        let amount_y_u128 = (amount_y as u128);
        
        // Calculate optimal token Y amount to add (based on ratio)
        let y_optimal_u128 = (amount_x_u128 * reserve_y_u128) / reserve_x_u128;
        let y_optimal = if (y_optimal_u128 > (18446744073709551615 as u128)) {
            18446744073709551615 // u64::MAX
        } else {
            (y_optimal_u128 as u64)
        };
        
        // Determine actual amounts to add
        if (y_optimal <= amount_y) {
            actual_x = amount_x;
            actual_y = y_optimal;
        } else {
            // Calculate optimal token X amount to add
            let x_optimal_u128 = (amount_y_u128 * reserve_x_u128) / reserve_y_u128;
            let x_optimal = if (x_optimal_u128 > (18446744073709551615 as u128)) {
                18446744073709551615 // u64::MAX
            } else {
                (x_optimal_u128 as u64)
            };
            
            actual_x = x_optimal;
            actual_y = amount_y;
        };
        
        // Calculate LP token amount, using u128 to avoid overflow
        let actual_x_u128 = (actual_x as u128);
        let actual_y_u128 = (actual_y as u128);
        let product = actual_x_u128 * actual_y_u128;
        let sqrt_product = u128::sqrt(product);
        
        lp_amount = if (sqrt_product > (18446744073709551615 as u128)) {
            18446744073709551615 // u64::MAX
        } else {
            (sqrt_product as u64)
        };
        
        // Split tokens, only use the actual amounts needed
        let coin_x_to_add;
        let coin_y_to_add;
        
        // Handle X token
        if (actual_x == amount_x) {
            // If we need to use all X tokens, use the entire coin
            coin_x_to_add = coin_x;
            // Create an empty X coin as return value
            coin_x = coin::zero<CoinTypeX>(ctx);
        } else {
            // Otherwise split the needed part
            coin_x_to_add = coin::split(&mut coin_x, actual_x, ctx);
        };
        
        // Handle Y token
        if (actual_y == amount_y) {
            // If we need to use all Y tokens, use the entire coin
            coin_y_to_add = coin_y;
            // Create an empty Y coin as return value
            coin_y = coin::zero<CoinTypeY>(ctx);
        } else {
            // Otherwise split the needed part
            coin_y_to_add = coin::split(&mut coin_y, actual_y, ctx);
        };
        
        // Add liquidity to the pool
        let coin_x_balance = coin::into_balance(coin_x_to_add);
        let coin_y_balance = coin::into_balance(coin_y_to_add);
        
        let added_x = balance::value(&coin_x_balance);
        let added_y = balance::value(&coin_y_balance);
        
        balance::join(&mut pool.reserve_x, coin_x_balance);
        balance::join(&mut pool.reserve_y, coin_y_balance);
        
        // Update LP token total supply
        pool.lp_supply = pool.lp_supply + lp_amount;
        
        // Create LP token
        let lp_coin = LPCoin<CoinTypeX, CoinTypeY> {
            id: object::new(ctx),
            amount: lp_amount,
        };
        
        // Emit add liquidity event
        event::emit(LiquidityAddedEvent {
            provider: tx_context::sender(ctx),
            pool_id: object::uid_to_address(&pool.id),
            amount_x: added_x,
            amount_y: added_y,
            lp_tokens: lp_amount,
        });
        
        (lp_coin, coin_x, coin_y)
    }

    /// Remove liquidity
    public fun remove_liquidity<CoinTypeX, CoinTypeY>(
        pool: &mut LiquidityPool<CoinTypeX, CoinTypeY>,
        lp_coin: LPCoin<CoinTypeX, CoinTypeY>,
        ctx: &mut TxContext
    ): (Coin<CoinTypeX>, Coin<CoinTypeY>) {
        let lp_amount = lp_coin.amount;
        let LPCoin { id, amount: _ } = lp_coin;
        object::delete(id);
        
        // Ensure LP token amount is not zero
        assert!(lp_amount > 0, E_ZERO_AMOUNT);
        assert!(lp_amount <= pool.lp_supply, E_INSUFFICIENT_LIQUIDITY);
        
        // Calculate token amounts to return, using u128 to avoid overflow
        let reserve_x = balance::value(&pool.reserve_x);
        let reserve_y = balance::value(&pool.reserve_y);
        
        let lp_amount_u128 = (lp_amount as u128);
        let reserve_x_u128 = (reserve_x as u128);
        let reserve_y_u128 = (reserve_y as u128);
        let lp_supply_u128 = (pool.lp_supply as u128);
        
        let amount_x_u128 = (lp_amount_u128 * reserve_x_u128) / lp_supply_u128;
        let amount_y_u128 = (lp_amount_u128 * reserve_y_u128) / lp_supply_u128;
        
        let amount_x = if (amount_x_u128 > (18446744073709551615 as u128)) {
            18446744073709551615 // u64::MAX
        } else {
            (amount_x_u128 as u64)
        };
        
        let amount_y = if (amount_y_u128 > (18446744073709551615 as u128)) {
            18446744073709551615 // u64::MAX
        } else {
            (amount_y_u128 as u64)
        };
        
        // Ensure returned amounts are not zero
        assert!(amount_x > 0, E_INSUFFICIENT_X_AMOUNT);
        assert!(amount_y > 0, E_INSUFFICIENT_Y_AMOUNT);
        
        // Withdraw tokens from the pool
        let coin_x = coin::from_balance(balance::split(&mut pool.reserve_x, amount_x), ctx);
        let coin_y = coin::from_balance(balance::split(&mut pool.reserve_y, amount_y), ctx);
        
        // Update LP token total supply
        pool.lp_supply = pool.lp_supply - lp_amount;
        
        // Emit remove liquidity event
        event::emit(LiquidityRemovedEvent {
            provider: tx_context::sender(ctx),
            pool_id: object::uid_to_address(&pool.id),
            amount_x,
            amount_y,
            lp_tokens: lp_amount,
        });
        
        (coin_x, coin_y)
    }

    /// Get reserves from the pool
    public fun get_reserves<CoinTypeX, CoinTypeY>(
        pool: &LiquidityPool<CoinTypeX, CoinTypeY>
    ): (u64, u64) {
        (balance::value(&pool.reserve_x), balance::value(&pool.reserve_y))
    }

    /// Get LP token supply
    public fun get_lp_supply<CoinTypeX, CoinTypeY>(
        pool: &LiquidityPool<CoinTypeX, CoinTypeY>
    ): u64 {
        pool.lp_supply
    }

    /// Get LP token amount
    public fun get_lp_amount<CoinTypeX, CoinTypeY>(
        lp_coin: &LPCoin<CoinTypeX, CoinTypeY>
    ): u64 {
        lp_coin.amount
    }

    /// Get coin name (helper function)
    fun get_coin_name<CoinType>(): String {
        let type_name = std::type_name::get<CoinType>();
        string::utf8(std::ascii::into_bytes(std::type_name::into_string(type_name)))
    }

    /// Get pool ID
    public fun get_pool_id<CoinTypeX, CoinTypeY>(
        pool: &LiquidityPool<CoinTypeX, CoinTypeY>
    ): &UID {
        &pool.id
    }

    /// Get fee percentage
    public fun get_fee_percent<CoinTypeX, CoinTypeY>(
        pool: &LiquidityPool<CoinTypeX, CoinTypeY>
    ): u64 {
        pool.fee_percent
    }

    /// Execute X->Y token swap
    public fun swap_x_to_y<CoinTypeX, CoinTypeY>(
        pool: &mut LiquidityPool<CoinTypeX, CoinTypeY>,
        coin_x: Coin<CoinTypeX>,
        amount_out: u64,
        ctx: &mut TxContext
    ): Coin<CoinTypeY> {
        let amount_in = coin::value(&coin_x);
        
        // Ensure amounts are not zero
        assert!(amount_in > 0, E_ZERO_AMOUNT);
        assert!(amount_out > 0, E_ZERO_AMOUNT);
        
        // Get current pool state
        let reserve_x = balance::value(&pool.reserve_x);
        let reserve_y = balance::value(&pool.reserve_y);
        
        // Ensure pool has sufficient liquidity
        assert!(reserve_x > 0 && reserve_y > 0, E_INSUFFICIENT_LIQUIDITY);
        
        // Ensure output amount doesn't exceed pool reserves
        assert!(amount_out < reserve_y, E_INSUFFICIENT_Y_AMOUNT);
        
        // Calculate K value before swap, using u128 to avoid overflow
        let reserve_x_u128 = (reserve_x as u128);
        let reserve_y_u128 = (reserve_y as u128);
        let k_before_u128 = reserve_x_u128 * reserve_y_u128;
        
        // Add input token to the pool
        let coin_in_balance = coin::into_balance(coin_x);
        balance::join(&mut pool.reserve_x, coin_in_balance);
        let out_balance = balance::split(&mut pool.reserve_y, amount_out);
        
        // Check K value invariant, using u128
        let new_reserve_x = balance::value(&pool.reserve_x);
        let new_reserve_y = balance::value(&pool.reserve_y);
        let new_reserve_x_u128 = (new_reserve_x as u128);
        let new_reserve_y_u128 = (new_reserve_y as u128);
        let k_after_u128 = new_reserve_x_u128 * new_reserve_y_u128;
        
        // K value should remain constant or increase (considering fees)
        assert!(k_after_u128 >= k_before_u128, E_K_VALUE_INVARIANT);
        
        coin::from_balance(out_balance, ctx)
    }

    /// Execute Y->X token swap
    public fun swap_y_to_x<CoinTypeX, CoinTypeY>(
        pool: &mut LiquidityPool<CoinTypeX, CoinTypeY>,
        coin_y: Coin<CoinTypeY>,
        amount_out: u64,
        ctx: &mut TxContext
    ): Coin<CoinTypeX> {
        let amount_in = coin::value(&coin_y);
        
        // Ensure amounts are not zero
        assert!(amount_in > 0, E_ZERO_AMOUNT);
        assert!(amount_out > 0, E_ZERO_AMOUNT);
        
        // Get current pool state
        let reserve_x = balance::value(&pool.reserve_x);
        let reserve_y = balance::value(&pool.reserve_y);
        
        // Ensure pool has sufficient liquidity
        assert!(reserve_x > 0 && reserve_y > 0, E_INSUFFICIENT_LIQUIDITY);
        
        // Ensure output amount doesn't exceed pool reserves
        assert!(amount_out < reserve_x, E_INSUFFICIENT_X_AMOUNT);
        
        // Calculate K value before swap, using u128 to avoid overflow
        let reserve_x_u128 = (reserve_x as u128);
        let reserve_y_u128 = (reserve_y as u128);
        let k_before_u128 = reserve_x_u128 * reserve_y_u128;
        
        // Add input token to the pool
        let coin_in_balance = coin::into_balance(coin_y);
        balance::join(&mut pool.reserve_y, coin_in_balance);
        let out_balance = balance::split(&mut pool.reserve_x, amount_out);
        
        // Check K value invariant, using u128
        let new_reserve_x = balance::value(&pool.reserve_x);
        let new_reserve_y = balance::value(&pool.reserve_y);
        let new_reserve_x_u128 = (new_reserve_x as u128);
        let new_reserve_y_u128 = (new_reserve_y as u128);
        let k_after_u128 = new_reserve_x_u128 * new_reserve_y_u128;
        
        // K value should remain constant or increase (considering fees)
        assert!(k_after_u128 >= k_before_u128, E_K_VALUE_INVARIANT);
        
        coin::from_balance(out_balance, ctx)
    }

    /// Calculate the value of a specific amount of LP tokens (expressed in tokens X and Y)
    public fun calculate_lp_value<CoinTypeX, CoinTypeY>(
        pool: &LiquidityPool<CoinTypeX, CoinTypeY>,
        lp_amount: u64
    ): (u64, u64) {
        let (reserve_x, reserve_y) = get_reserves(pool);
        let lp_supply = pool.lp_supply;
        
        if (lp_supply == 0) {
            return (0, 0)
        };

        // Use u128 for large number calculations
        let x_value = ((lp_amount as u128) * (reserve_x as u128) / (lp_supply as u128) as u64);
        let y_value = ((lp_amount as u128) * (reserve_y as u128) / (lp_supply as u128) as u64);
        
        (x_value, y_value)
    }
    
    /// Calculate liquidity provider's profit (compared to initial liquidity provided)
    public fun calculate_lp_profit<CoinTypeX, CoinTypeY>(
        pool: &LiquidityPool<CoinTypeX, CoinTypeY>,
        lp_amount: u64,
        initial_x: u64,
        initial_y: u64
    ): (u64, u64, bool, bool) {
        // Calculate current value of LP tokens
        let (current_x, current_y) = calculate_lp_value(pool, lp_amount);
        
        // Calculate profit for tokens X and Y (may be negative)
        let x_profit = if (current_x > initial_x) { current_x - initial_x } else { 0 };
        let y_profit = if (current_y > initial_y) { current_y - initial_y } else { 0 };
        
        // Determine if there's profit
        let has_x_profit = current_x > initial_x;
        let has_y_profit = current_y > initial_y;
        
        (x_profit, y_profit, has_x_profit, has_y_profit)
    }
    
    /// Check if two types are the same (helper function)
    fun is_same_type<T1, T2>(): bool {
        get_coin_name<T1>() == get_coin_name<T2>()
    }
}