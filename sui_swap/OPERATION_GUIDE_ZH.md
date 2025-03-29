# SUI Swap 操作指南

本文档提供了部署 SUI Swap 合约和使用 `sui client` 命令行工具与之交互的详细说明。

## 前提条件

在开始之前，请确保您已经：

1. 安装了 Sui 命令行工具 (`sui`)
2. 配置了 Sui 钱包并拥有足够的 SUI 代币用于支付 Gas 费用
3. 克隆了 SUI Swap 代码库

## 一、部署合约

### 1. 编译合约

```bash
# 进入项目根目录
cd sui_swap

# 编译合约
sui move build
```

编译成功后，编译后的字节码将生成在 `build` 目录中。

### 2. 测试合约

在部署前，建议对合约进行全面测试以确保功能正常。SUI Swap 提供了多种测试方法：

```bash
# 运行所有单元测试
sui move test
```

### 3. 发布合约

完成测试和环境配置后，将合约发布到测试网：

```bash
# 发布合约到测试网
sui client publish
```

发布成功后，控制台将输出重要信息，请记录以下关键 ID，后续操作需要使用：
- `packageId`：SUI Swap 合约及测试代币模块的包 ID，用于调用任何函数
- `factoryId`：Factory 共享对象 ID，用于创建流动性池
- `treasuryCapXId`：TEST_COIN_X 代币的铸币能力对象 ID (共享对象)，用于铸造X测试代币
- `treasuryCapYId`：TEST_COIN_Y 代币的铸币能力对象 ID (共享对象)，用于铸造Y测试代币

> **注意**：测试代币模块与SUI Swap主合约在同一个包中，因此它们共享同一个包ID。发布后，请查看输出中的 "Created Objects" 部分，找到类型为 "TreasuryCap<TEST_COIN_X>" 和 "TreasuryCap<TEST_COIN_Y>" 的对象，它们是共享对象，任何人都可以使用这些对象铸造测试代币。元数据对象已被冻结，不需要特别记录。

### 4. 验证部署

发布后，验证合约是否成功部署：

```bash
# 查询 packageId 详情
sui client object <packageId>

# 查询 Factory 对象详情
sui client object <factoryId>

# 查询测试代币X的铸币能力对象
sui client object <treasuryCapXId>

# 查询测试代币Y的铸币能力对象
sui client object <treasuryCapYId>

# 查看您拥有的所有对象
sui client objects
```


## 二、合约交互示例

以下示例使用 `sui client` 命令行工具与合约交互。使用前，请将占位符替换为实际的对象 ID。

### 1. 创建代币（可选，如果您已有测试代币可以跳过）

SUI Swap 项目已包含两个测试代币模块，它们与主合约位于同一个包中，您可以直接使用它们来创建测试代币：

```bash

# - SUI_SWAP_PACKAGE_ID: 整个包的ID
# - FACTORY_ID: 工厂对象ID
# - TREASURY_CAP_X_ID: TEST_COIN_X代币的铸币能力对象ID（共享对象）
# - TREASURY_CAP_Y_ID: TEST_COIN_Y代币的铸币能力对象ID（共享对象）

# 铸造TEST_COIN_X代币
sui client call --package <SUI_SWAP_PACKAGE_ID> --module test_coin_x --function mint \
  --args <TREASURY_CAP_X_ID> 1000000000 <YOUR_ADDRESS> \
  --gas-budget 10000000

# 铸造TEST_COIN_Y代币
sui client call --package <SUI_SWAP_PACKAGE_ID> --module test_coin_y --function mint \
  --args <TREASURY_CAP_Y_ID> 1000000000 <YOUR_ADDRESS> \
  --gas-budget 10000000
```

> **提示**：使用这些测试代币模块是最简单的方法，它们会创建两种测试代币（TEST_COIN_X和TEST_COIN_Y）供您测试SUI Swap。铸币能力对象是共享的，这意味着任何人都可以铸造这些测试代币，非常方便测试。
> 
> **重要说明**: 
> 1. 测试代币模块与SUI Swap主合约位于同一个包中，因此它们共享相同的包ID
> 2. 铸币能力对象（TreasuryCap）是共享对象，任何人都可以调用mint函数铸造测试代币
> 3. 元数据对象（Metadata）是冻结对象，不能被修改

### 2. 创建流动性池

创建流动性池时，需要使用上一步获得的测试代币：

```bash
# 使用默认费率创建流动性池
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function create_pool_with_default_fee \
  --args <FACTORY_ID> <COIN_X_ID> <COIN_Y_ID> \
  --type-args <SUI_SWAP_PACKAGE_ID>::test_coin_x::TEST_COIN_X <SUI_SWAP_PACKAGE_ID>::test_coin_y::TEST_COIN_Y \
  --gas-budget 10000000

# 或使用自定义费率创建流动性池
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function create_pool \
  --args <FACTORY_ID> <COIN_X_ID> <COIN_Y_ID> 30 \
  --type-args <SUI_SWAP_PACKAGE_ID>::test_coin_x::TEST_COIN_X <SUI_SWAP_PACKAGE_ID>::test_coin_y::TEST_COIN_Y \
  --gas-budget 10000000
```

> **重要区分**:
> - `<SUI_SWAP_PACKAGE_ID>`: SUI Swap 合约的包 ID，同时也是测试代币模块的包 ID
> - `<FACTORY_ID>`: SUI Swap 工厂对象 ID
> - `<COIN_X_ID>` 和 `<COIN_Y_ID>`: 您钱包中持有的测试代币实例对象ID

创建成功后，交易结果将返回流动性池对象 ID (`POOL_ID`)。请记录此 ID 用于后续操作。

### 3. 添加流动性

```bash
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function add_liquidity \
  --args <POOL_ID> <COIN_X_ID> <COIN_Y_ID> \
  --type-args <SUI_SWAP_PACKAGE_ID>::test_coin_x::TEST_COIN_X <SUI_SWAP_PACKAGE_ID>::test_coin_y::TEST_COIN_Y \
  --gas-budget 10000000
```

添加成功后，您将收到 LP 代币和可能的剩余代币。请记录 LP 代币对象 ID (`LP_COIN_ID`) 用于后续操作。

### 4. 代币交换

```bash
# 将代币 X 交换为代币 Y
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function swap_x_to_y \
  --args <POOL_ID> <COIN_X_ID> <MIN_AMOUNT_OUT> <DEADLINE> \
  --type-args <SUI_SWAP_PACKAGE_ID>::test_coin_x::TEST_COIN_X <SUI_SWAP_PACKAGE_ID>::test_coin_y::TEST_COIN_Y \
  --gas-budget 10000000

# 将代币 Y 交换为代币 X
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function swap_y_to_x \
  --args <POOL_ID> <COIN_Y_ID> <MIN_AMOUNT_OUT> <DEADLINE> \
  --type-args <SUI_SWAP_PACKAGE_ID>::test_coin_x::TEST_COIN_X <SUI_SWAP_PACKAGE_ID>::test_coin_y::TEST_COIN_Y \
  --gas-budget 10000000
```

参数说明：
- `<MIN_AMOUNT_OUT>`：最小输出金额，用于防止过大的滑点
- `<DEADLINE>`：交易截止时间戳（Unix 时间戳，单位：秒）
- `<SUI_SWAP_PACKAGE_ID>`：SUI Swap 合约的包 ID

### 5. 移除流动性

```bash
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function remove_liquidity \
  --args <POOL_ID> <LP_COIN_ID> \
  --type-args <SUI_SWAP_PACKAGE_ID>::test_coin_x::TEST_COIN_X <SUI_SWAP_PACKAGE_ID>::test_coin_y::TEST_COIN_Y \
  --gas-budget 10000000
```

移除成功后，您将收到代币 X 和代币 Y，以及累积的手续费。

### 6. 更新工厂默认费率（仅工厂所有者）

```bash
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function update_default_fee_percent \
  --args <FACTORY_ID> <NEW_FEE_PERCENT> \
  --gas-budget 10000000
```

参数说明：
- `<NEW_FEE_PERCENT>`：新的默认费率（例如：30 表示 0.3%）

### 7. 转移工厂所有权（仅工厂所有者）

```bash
sui client call --package <SUI_SWAP_PACKAGE_ID> --module sui_swap --function transfer_factory_ownership \
  --args <FACTORY_ID> <NEW_OWNER_ADDRESS> \
  --gas-budget 10000000
```

## 三、在 SUI 区块链浏览器中查看对象

您可以在 SUI 区块链浏览器中查看对象详情：

- 测试网浏览器：https://testnet.suivision.xyz/
- 主网浏览器：https://suivision.xyz/

输入对象 ID 即可查看详细信息，如流动性池余额、所有权等。

## 四、常见问题解答

### 1. 交易失败的常见原因

- Gas 预算不足：增加 `--gas-budget` 参数的值
- 代币余额不足：确保您有足够的代币进行操作
- 权限问题：某些操作只有工厂所有者才能执行
- 类型错误：确保您使用了正确的类型参数

### 2. 如何查询对象信息？

```bash
# 查询对象详情
sui client object <OBJECT_ID>

# 查询流动性池详情
sui client object <POOL_ID>

# 查询工厂详情
sui client object <FACTORY_ID>
```


### 3. 测试代币模块相关问题

#### Q: 内置的测试代币与自定义代币有什么区别？
A: 内置的测试代币模块提供了两种预定义的代币类型（TEST_COIN_X和TEST_COIN_Y），方便快速测试。而自定义代币需要您自己编写和发布代币模块。功能上没有区别，都可以用于创建流动性池和交换操作。内置测试代币的铸币能力是共享对象，任何人都可以铸造，非常适合测试环境。

#### Q: 如何查看测试代币的铸币能力对象？
A: 由于铸币能力是共享对象，您可以使用以下命令查看：
```bash
# 查看TEST_COIN_X的铸币能力共享对象
sui client object <TREASURY_CAP_X_ID>

# 查看TEST_COIN_Y的铸币能力共享对象
sui client object <TREASURY_CAP_Y_ID>
```

#### Q: 是否有限制谁可以铸造测试代币？
A: 没有限制。测试代币的铸币能力是共享对象，任何人都可以调用`mint`函数铸造任意数量的测试代币。这是为了方便测试而设计的。

#### Q: 测试代币默认的小数位数是多少？
A: 测试代币默认使用9位小数，与大多数加密货币标准一致。

## 五、重要注意事项

1. 执行交换操作时，确保设置适当的 `min_amount_out` 以防止因价格波动造成损失
2. 交易截止时间(deadline)应设置为未来的时间戳，单位为秒
3. 在主网上操作前，建议先在测试网上进行充分测试
4. 记录所有重要对象 ID，以避免失去访问权限