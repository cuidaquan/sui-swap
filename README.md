# SUI Swap

SUI Swap is an Automated Market Maker (AMM) protocol built on the SUI blockchain, utilizing the constant product model (x*y=k) for token swaps. This project implements a complete set of Decentralized Exchange (DEX) core functionalities, enabling users to add liquidity and perform token swaps.

## Related Documentation

- [Deployment and Usage Guide](OPERATION_GUIDE.md): Detailed deployment steps and sui client call examples

## Core Features

- **Liquidity Pool Management**: Create and manage trading pairs between any two tokens
- **Add/Remove Liquidity**: Users can add liquidity to receive LP tokens and burn LP tokens to retrieve original tokens
- **Token Swaps**: Efficient token exchange based on constant product formula
- **Fee Mechanism**: Configurable transaction fees for each trade, rewarding liquidity providers
- **LP Token Value Calculation**: Support for calculating real-time value and profit of LP tokens

## Project Architecture

The project consists of four main modules:

- `factory.move`: Factory contract responsible for creating and registering liquidity pools
- `liquidity_pool.move`: Liquidity pool implementation, managing token reserves and swap logic
- `swap.move`: Swap logic and price calculation
- `sui_swap.move`: User interface functions

## Permission Design

This project implements secure permission control mechanisms:

- **Liquidity Pool Creation**: Only factory owner can create new liquidity pools, ensuring quality control
- **Fee Management**: Only factory owner can update default transaction fees
- **Ownership Transfer**: Factory owner can transfer ownership to a new address

## User Guide

1. **Create Factory**:
   - Factory contract is automatically created during initialization
   - Initial deployer becomes the factory owner
   - Default fee rate is 0.3%

2. **Create Liquidity Pool**:
   - Only factory owner can create new liquidity pools
   - Supports two creation methods:
     - Create with custom fee rate
     - Create with default fee rate (0.3%)
   - Initial token amounts are required for creation

3. **Add Liquidity**:
   - Any user can add liquidity to existing pools
   - Receive LP tokens proportional to contribution
   - Automatic handling of mismatched token amounts with remaining tokens returned
   - Supports adding tokens in any ratio

4. **Token Swaps**:
   - Supports bidirectional token swaps (X->Y and Y->X)
   - Users can perform token swaps in liquidity pools
   - Supports setting minimum output amount and deadline
   - Automatic slippage protection
   - Automatic rollback on transaction failure

5. **Remove Liquidity**:
   - LP token holders can remove liquidity at any time
   - Receive original tokens and accumulated fees proportionally
   - Supports partial or complete removal

6. **LP Token Value Calculation**:
   - Calculate token value for any amount of LP tokens
   - Calculate profit for LP token holders

7. **Factory Management**:
   - Factory owner can update default transaction fees
   - Supports factory ownership transfer
   - View all created liquidity pools

## Technical Features

- **Large Number Handling**: Uses u128 for large number calculations to prevent integer overflow
- **Precise Calculations**: Implements precise mathematical calculations to avoid rounding errors
- **Event System**: Complete event logging for off-chain tracking and analysis
- **Type Safety**: Strict type checking ensures transaction safety

## Security Considerations

- Precise mathematical calculations to prevent overflow and rounding errors
- Permission checks for all critical operations
- Comprehensive test coverage ensures functional correctness
- Uses u128 for large number calculations to prevent integer overflow
- Strict type checking and boundary condition validation
- Complete error handling mechanism 