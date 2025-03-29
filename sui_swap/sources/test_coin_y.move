module sui_swap::test_coin_y {
    use sui::coin::{Self, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::option;

    /// OTW (One-Time Witness)
    public struct TEST_COIN_Y has drop {}

    /// Module initialization function - Creates test token Y
    fun init(witness: TEST_COIN_Y, ctx: &mut TxContext) {
        // Create test token Y
        let (treasury_cap, metadata) = coin::create_currency(
            witness, 
            9, // Decimals
            b"TCOINY", // Symbol
            b"Test Coin Y", // Name
            b"Test coin Y for SUI Swap testing", // Description
            option::none(), // Icon URL
            ctx
        );

        // Freeze metadata and share treasury cap
        transfer::public_freeze_object(metadata);
        transfer::public_share_object(treasury_cap);
    }

    /// Public function for minting tokens
    public entry fun mint(
        treasury_cap: &mut TreasuryCap<TEST_COIN_Y>, 
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }
} 