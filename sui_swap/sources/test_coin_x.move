module sui_swap::test_coin_x {
    use sui::coin::{Self, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::option;

    /// OTW (One-Time Witness)
    public struct TEST_COIN_X has drop {}

    /// Module initialization function - Creates test token X
    fun init(witness: TEST_COIN_X, ctx: &mut TxContext) {
        // Create test token X
        let (treasury_cap, metadata) = coin::create_currency(
            witness, 
            9, // Decimals
            b"TCOINX", // Symbol
            b"Test Coin X", // Name
            b"Test coin X for SUI Swap testing", // Description
            option::none(), // Icon URL
            ctx
        );

        // Freeze metadata and share treasury cap
        transfer::public_freeze_object(metadata);
        transfer::public_share_object(treasury_cap);
    }

    /// Public function for minting tokens
    public entry fun mint(
        treasury_cap: &mut TreasuryCap<TEST_COIN_X>, 
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }
} 