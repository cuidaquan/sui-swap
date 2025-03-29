module sui_swap::test_coin_x {
    use sui::coin::{Self, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::option;

    /// OTW (One-Time Witness)
    public struct TEST_COIN_X has drop {}

    /// 模块初始化函数 - 创建测试代币X
    fun init(witness: TEST_COIN_X, ctx: &mut TxContext) {
        // 创建测试代币X
        let (treasury_cap, metadata) = coin::create_currency(
            witness, 
            9, // 小数位数
            b"TCOINX", // 符号
            b"Test Coin X", // 名称
            b"Test coin X for SUI Swap testing", // 描述
            option::none(), // 图标URL
            ctx
        );

        // 将元数据冻结，铸币能力共享
        transfer::public_freeze_object(metadata);
        transfer::public_share_object(treasury_cap);
    }

    /// 铸造代币的公共函数
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