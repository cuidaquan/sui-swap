#[allow(duplicate_alias, lint(share_owned))]
module sui_swap::factory {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::Coin;
    use sui::table::{Self, Table};
    use sui::event;
    use std::string::{Self, String};

    use sui_swap::liquidity_pool::{Self};

    /// Factory structure, manages all liquidity pools
    public struct Factory has key {
        id: UID,
        pools: Table<String, address>,
        pool_list: vector<String>,
        default_fee_percent: u64,
        owner: address,
    }

    /// Factory creation event
    public struct FactoryCreatedEvent has copy, drop {
        factory_id: address,
        owner: address,
        default_fee_percent: u64,
    }

    /// Pool creation event
    public struct PoolCreatedByFactoryEvent has copy, drop {
        factory_id: address,
        pool_id: address,
        pool_key: String,
        coin_x_type: String,
        coin_y_type: String,
    }

    /// Error codes
    const E_NOT_OWNER: u64 = 0;
    const E_POOL_ALREADY_EXISTS: u64 = 1;
    const E_POOL_DOES_NOT_EXIST: u64 = 2;
    const E_INVALID_FEE_PERCENT: u64 = 3;
    const E_SAME_COIN_TYPE: u64 = 4;

    /// Create factory
    public fun create_factory(
        default_fee_percent: u64,
        ctx: &mut TxContext
    ) {
        // Validate fee rate is within reasonable range (0-5%)
        assert!(default_fee_percent <= 500, E_INVALID_FEE_PERCENT);
        
        let factory_id = object::new(ctx);
        let factory_address = object::uid_to_address(&factory_id);
        let owner = tx_context::sender(ctx);
        
        let factory = Factory {
            id: factory_id,
            pools: table::new(ctx),
            pool_list: vector::empty(),
            default_fee_percent,
            owner,
        };
        
        // Emit factory creation event
        event::emit(FactoryCreatedEvent {
            factory_id: factory_address,
            owner,
            default_fee_percent,
        });
        
        // Share factory object
        transfer::share_object(factory);
    }

    /// Create liquidity pool
    public fun create_pool<CoinTypeX, CoinTypeY>(
        factory: &mut Factory,
        coin_x: Coin<CoinTypeX>,
        coin_y: Coin<CoinTypeY>,
        fee_percent: u64,
        ctx: &mut TxContext
    ) {
        // Only owner can create pools
        assert!(tx_context::sender(ctx) == factory.owner, E_NOT_OWNER);
        
        // Ensure token types are different
        assert!(!is_same_type<CoinTypeX, CoinTypeY>(), E_SAME_COIN_TYPE);
        
        // Validate fee rate is within reasonable range (0-5%)
        assert!(fee_percent <= 500, E_INVALID_FEE_PERCENT);
        
        // Generate pool key
        let pool_key = get_pool_key<CoinTypeX, CoinTypeY>();
        
        // Ensure pool doesn't exist
        assert!(!table::contains(&factory.pools, pool_key), E_POOL_ALREADY_EXISTS);
        
        // Create liquidity pool
        let pool = liquidity_pool::create_pool(coin_x, coin_y, fee_percent, ctx);
        let pool_id = object::uid_to_address(liquidity_pool::get_pool_id(&pool));
        
        // Add pool to factory
        table::add(&mut factory.pools, pool_key, pool_id);
        vector::push_back(&mut factory.pool_list, pool_key);
        
        // Emit pool creation event
        event::emit(PoolCreatedByFactoryEvent {
            factory_id: object::uid_to_address(&factory.id),
            pool_id,
            pool_key,
            coin_x_type: get_coin_name<CoinTypeX>(),
            coin_y_type: get_coin_name<CoinTypeY>(),
        });
        
        // Share pool object
        transfer::public_share_object(pool);
    }

    /// Create liquidity pool with default fee
    public fun create_pool_with_default_fee<CoinTypeX, CoinTypeY>(
        factory: &mut Factory,
        coin_x: Coin<CoinTypeX>,
        coin_y: Coin<CoinTypeY>,
        ctx: &mut TxContext
    ) {
        let default_fee = factory.default_fee_percent;
        create_pool<CoinTypeX, CoinTypeY>(
            factory,
            coin_x,
            coin_y,
            default_fee,
            ctx
        )
    }

    /// Update default fee rate
    public fun update_default_fee_percent(
        factory: &mut Factory,
        new_fee_percent: u64,
        ctx: &mut TxContext
    ) {
        // Only owner can update fee rate
        assert!(tx_context::sender(ctx) == factory.owner, E_NOT_OWNER);
        
        // Validate fee rate is within reasonable range (0-5%)
        assert!(new_fee_percent <= 500, E_INVALID_FEE_PERCENT);
        
        factory.default_fee_percent = new_fee_percent;
    }

    /// Transfer factory ownership
    public fun transfer_ownership(
        factory: &mut Factory,
        new_owner: address,
        ctx: &mut TxContext
    ) {
        // Only owner can transfer ownership
        assert!(tx_context::sender(ctx) == factory.owner, E_NOT_OWNER);
        
        factory.owner = new_owner;
    }

    /// Get pool address
    public fun get_pool_address<CoinTypeX, CoinTypeY>(
        factory: &Factory
    ): address {
        let pool_key = get_pool_key<CoinTypeX, CoinTypeY>();
        assert!(table::contains(&factory.pools, pool_key), E_POOL_DOES_NOT_EXIST);
        *table::borrow(&factory.pools, pool_key)
    }

    /// Get all pool keys
    public fun get_all_pool_keys(
        factory: &Factory
    ): &vector<String> {
        &factory.pool_list
    }

    /// Get pool count
    public fun get_pool_count(
        factory: &Factory
    ): u64 {
        vector::length(&factory.pool_list)
    }

    /// Get default fee rate
    public fun get_default_fee_percent(
        factory: &Factory
    ): u64 {
        factory.default_fee_percent
    }

    /// Get factory owner
    public fun get_owner(
        factory: &Factory
    ): address {
        factory.owner
    }

    /// Generate pool key (helper function)
    fun get_pool_key<CoinTypeX, CoinTypeY>(): String {
        let type_x = get_coin_name<CoinTypeX>();
        let type_y = get_coin_name<CoinTypeY>();
        
        // Ensure types are sorted lexicographically to ensure the same token pair always generates the same key
        if (string_compare(&type_x, &type_y) <= 0) {
            let mut key = string::utf8(b"");
            string::append(&mut key, type_x);
            string::append(&mut key, string::utf8(b":"));
            string::append(&mut key, type_y);
            key
        } else {
            let mut key = string::utf8(b"");
            string::append(&mut key, type_y);
            string::append(&mut key, string::utf8(b":"));
            string::append(&mut key, type_x);
            key
        }
    }

    /// String comparison (helper function)
    fun string_compare(a: &String, b: &String): u8 {
        let a_bytes = string::as_bytes(a);
        let b_bytes = string::as_bytes(b);
        
        let a_length = vector::length(a_bytes);
        let b_length = vector::length(b_bytes);
        
        let mut i = 0;
        let min_length = if (a_length < b_length) { a_length } else { b_length };
        
        while (i < min_length) {
            let a_byte = *vector::borrow(a_bytes, i);
            let b_byte = *vector::borrow(b_bytes, i);
            
            if (a_byte < b_byte) {
                return 0 // a < b
            } else if (a_byte > b_byte) {
                return 2 // a > b
            };
            
            i = i + 1;
        };
        
        if (a_length < b_length) {
            0 // a < b
        } else if (a_length > b_length) {
            2 // a > b
        } else {
            1 // a == b
        }
    }

    /// Check if two types are the same (helper function)
    fun is_same_type<T1, T2>(): bool {
        get_coin_name<T1>() == get_coin_name<T2>()
    }

    /// Get coin name (helper function)
    fun get_coin_name<CoinType>(): String {
        let type_name = std::type_name::get<CoinType>();
        string::utf8(std::ascii::into_bytes(std::type_name::into_string(type_name)))
    }
}