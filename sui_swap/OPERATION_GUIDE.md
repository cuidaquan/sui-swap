# SUI Swap Operation Guide

This document provides detailed instructions for deploying SUI Swap contracts and interacting with them using the `sui client` command-line tool.

## Prerequisites

Before getting started, make sure you have:

1. Installed the Sui command-line tool (`sui`)
2. Configured your Sui wallet with sufficient SUI tokens for gas fees
3. Cloned the SUI Swap repository

## I. Deploying the Contract

### 1. Compile the Contract

```bash
# Navigate to the project root directory
cd sui_swap

# Compile the contract
sui move build
```

After successful compilation, bytecode will be generated in the `build` directory.

### 2. Test the Contract

Before deployment, it's recommended to thoroughly test the contract to ensure functionality. SUI Swap provides various testing methods:

```bash
# Run all unit tests
sui move test
```

### 3. Publish the Contract

After completing testing and environment configuration, publish the contract to the testnet:

```bash
# Publish contract to testnet
sui client publish
```

After successful publication, the console will output important information. Record the following key IDs for future operations:
- `packageId`: The package ID for both SUI Swap contracts and test token modules, used for calling any function
- `factoryId`: Factory shared object ID, used for creating liquidity pools
- `treasuryCapXId`: The treasury capability object ID for TEST_COIN_X token (shared object), used for minting test token X
- `treasuryCapYId`: The treasury capability object ID for TEST_COIN_Y token (shared object), used for minting test token Y

> **Note**: The test token modules are included in the same package as the main SUI Swap contract, so they share the same package ID. After publication, check the "Created Objects" section in the output to find objects of type "TreasuryCap<TEST_COIN_X>" and "TreasuryCap<TEST_COIN_Y>". These are shared objects that anyone can use to mint test tokens. The metadata objects are frozen and don't need to be recorded.

### 4. Verify Deployment

After publishing, verify that the contract was successfully deployed:

```bash
# Query packageId details
sui client object <packageId>

# Query Factory object details
sui client object <factoryId>

# Query test token X treasury capability object
sui client object <treasuryCapXId>

# Query test token Y treasury capability object
sui client object <treasuryCapYId>

# View all objects you own
sui client objects
```

## II. Contract Interaction Examples

The following examples use the `sui client` command-line tool to interact with the contract. Before using, replace placeholders with actual object IDs.

### 1. Create Tokens (Optional, Skip if You Already Have Test Tokens)

The SUI Swap project includes two test token modules that are in the same package as the main contract. You can use them to create test tokens:

```bash
# Record these important IDs:
# - SUI_SWAP_PACKAGE_ID: ID of the entire package
# - FACTORY_ID: Factory object ID
# - TREASURY_CAP_X_ID: Treasury capability object ID for TEST_COIN_X token (shared object)
# - TREASURY_CAP_Y_ID: Treasury capability object ID for TEST_COIN_Y token (shared object)

# Mint TEST_COIN_X tokens
sui client call --package <SUI_SWAP_PACKAGE_ID> --module test_coin_x --function mint \
  --args <TREASURY_CAP_X_ID> 1000000000 <YOUR_ADDRESS> \
  --gas-budget 10000000

# Mint TEST_COIN_Y tokens
sui client call --package <SUI_SWAP_PACKAGE_ID> --module test_coin_y --function mint \
  --args <TREASURY_CAP_Y_ID> 1000000000 <YOUR_ADDRESS> \
  --gas-budget 10000000
```

> **Tip**: Using these test token modules is the simplest method. They create two test tokens (TEST_COIN_X and TEST_COIN_Y) for testing SUI Swap. The treasury capability objects are shared, meaning anyone can mint these test tokens, which is very convenient for testing.
> 
> **Important Notes**: 
> 1. The test token modules are in the same package as the main SUI Swap contract, so they share the same package ID
> 2. The treasury capability objects (TreasuryCap) are shared objects, allowing anyone to call the mint function to create test tokens
> 3. The metadata objects (Metadata) are frozen objects and cannot be modified

### 2. Create a Liquidity Pool

When creating a liquidity pool, use the test tokens obtained in the previous step:

```bash
# Create a liquidity pool with default fee rate
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function create_pool_with_default_fee \
  --args <FACTORY_ID> <COIN_X_ID> <COIN_Y_ID> \
  --type-args <SUI_SWAP_PACKAGE_ID>::test_coin_x::TEST_COIN_X <SUI_SWAP_PACKAGE_ID>::test_coin_y::TEST_COIN_Y \
  --gas-budget 10000000

# Or create a liquidity pool with custom fee rate
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function create_pool \
  --args <FACTORY_ID> <COIN_X_ID> <COIN_Y_ID> 30 \
  --type-args <SUI_SWAP_PACKAGE_ID>::test_coin_x::TEST_COIN_X <SUI_SWAP_PACKAGE_ID>::test_coin_y::TEST_COIN_Y \
  --gas-budget 10000000
```

> **Important distinction**:
> - `<SUI_SWAP_PACKAGE_ID>`: The package ID for the SUI Swap contract, which is also the package ID for the test token modules
> - `<FACTORY_ID>`: SUI Swap factory object ID
> - `<COIN_X_ID>` and `<COIN_Y_ID>`: The test token instance object IDs in your wallet

After successful creation, the transaction result will return a liquidity pool object ID (`POOL_ID`). Record this ID for subsequent operations.

### 3. Add Liquidity

```bash
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function add_liquidity \
  --args <POOL_ID> <COIN_X_ID> <COIN_Y_ID> \
  --type-args <SUI_SWAP_PACKAGE_ID>::test_coin_x::TEST_COIN_X <SUI_SWAP_PACKAGE_ID>::test_coin_y::TEST_COIN_Y \
  --gas-budget 10000000
```

After successful addition, you will receive LP tokens and possibly remaining tokens. Record the LP token object ID (`LP_COIN_ID`) for subsequent operations.

### 4. Token Exchange

```bash
# Exchange Token X for Token Y
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function swap_x_to_y \
  --args <POOL_ID> <COIN_X_ID> <MIN_AMOUNT_OUT> <DEADLINE> \
  --type-args <SUI_SWAP_PACKAGE_ID>::test_coin_x::TEST_COIN_X <SUI_SWAP_PACKAGE_ID>::test_coin_y::TEST_COIN_Y \
  --gas-budget 10000000

# Exchange Token Y for Token X
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function swap_y_to_x \
  --args <POOL_ID> <COIN_Y_ID> <MIN_AMOUNT_OUT> <DEADLINE> \
  --type-args <SUI_SWAP_PACKAGE_ID>::test_coin_x::TEST_COIN_X <SUI_SWAP_PACKAGE_ID>::test_coin_y::TEST_COIN_Y \
  --gas-budget 10000000
```

Parameter explanation:
- `<MIN_AMOUNT_OUT>`: Minimum output amount, used to prevent excessive slippage
- `<DEADLINE>`: Transaction deadline timestamp (Unix timestamp, in seconds)
- `<SUI_SWAP_PACKAGE_ID>`: The package ID for the SUI Swap contract

### 5. Remove Liquidity

```bash
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function remove_liquidity \
  --args <POOL_ID> <LP_COIN_ID> \
  --type-args <SUI_SWAP_PACKAGE_ID>::test_coin_x::TEST_COIN_X <SUI_SWAP_PACKAGE_ID>::test_coin_y::TEST_COIN_Y \
  --gas-budget 10000000
```

After successful removal, you will receive tokens X and Y, as well as accumulated fees.

### 6. Update Factory Default Fee Rate (Factory Owner Only)

```bash
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function update_default_fee_percent \
  --args <FACTORY_ID> <NEW_FEE_PERCENT> \
  --gas-budget 10000000
```

Parameter explanation:
- `<NEW_FEE_PERCENT>`: New default fee rate (e.g., 30 represents 0.3%)

### 7. Transfer Factory Ownership (Factory Owner Only)

```bash
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function transfer_factory_ownership \
  --args <FACTORY_ID> <NEW_OWNER_ADDRESS> \
  --gas-budget 10000000
```

## III. Viewing Objects in the SUI Blockchain Explorer

You can view object details in the SUI blockchain explorer:

- Testnet explorer: https://testnet.suivision.xyz/
- Mainnet explorer: https://suivision.xyz/

Enter an object ID to view detailed information, such as liquidity pool balances, ownership, etc.

## IV. Frequently Asked Questions

### 1. Common Causes of Transaction Failures

- Insufficient gas budget: Increase the value of the `--gas-budget` parameter
- Insufficient token balance: Ensure you have enough tokens for the operation
- Permission issues: Some operations can only be performed by the factory owner
- Type errors: Ensure you're using the correct type parameters

### 2. How to Query Object Information?

```bash
# Query object details
sui client object <OBJECT_ID>

# Query liquidity pool details
sui client object <POOL_ID>

# Query factory details
sui client object <FACTORY_ID>
```

### 3. Test Token Module Related Questions

#### Q: What's the difference between built-in test tokens and custom tokens?
A: The built-in test token modules provide two predefined token types (TEST_COIN_X and TEST_COIN_Y) for quick testing. Custom tokens require you to write and publish your own token modules. There's no functional difference; both can be used for creating liquidity pools and exchange operations. The built-in test tokens have shared treasury capabilities, allowing anyone to mint them, which is ideal for testing environments.

#### Q: How to view the test token treasury capability objects?
A: Since the treasury capabilities are shared objects, you can view them using the following commands:
```bash
# View the TEST_COIN_X treasury capability shared object
sui client object <TREASURY_CAP_X_ID>

# View the TEST_COIN_Y treasury capability shared object
sui client object <TREASURY_CAP_Y_ID>
```

#### Q: Are there any restrictions on who can mint test tokens?
A: No restrictions. The test tokens' treasury capabilities are shared objects, allowing anyone to call the `mint` function to create any amount of test tokens. This is designed for testing convenience.

#### Q: What's the default decimal places for test tokens?
A: Test tokens use 9 decimal places by default, consistent with most cryptocurrency standards.

## V. Important Notes

1. When performing exchange operations, make sure to set an appropriate `min_amount_out` to prevent losses due to price volatility
2. Transaction deadline (deadline) should be set to a future timestamp, in seconds
3. Before operating on the mainnet, it's recommended to thoroughly test on the testnet
4. Record all important object IDs to avoid losing access 