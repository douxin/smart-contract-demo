# EIP-712 Typed structured data hashing and signing

## 如何运行本项目

```bash
cd $PROJECT_DIR
npm i
```

安装完成后，可以使用下面的命令进行运行测试代码

```bash
npx hardhat test
```

## 问题

传统方式签名时，用户只能看到一串字符，用户是无法理解签名的是什么内容，如图 1。这就会给用户带来了风险，如果用户是在一个有风险的网站上进行签名，那么就可能造成资产的损失。
![图 1](https://eips.ethereum.org/assets/eip-712/eth_sign.png)

## 解决方案

为了解决这个问题，[EIP-712](https://eips.ethereum.org/EIPS/eip-712) 提出了一个解决方案，它通过对结构化的数据进行签名，如图 2，用户在签名时可以清晰的知道自己所签名的内容是什么，从而避免对风险内容的签名。
![图 2](https://eips.ethereum.org/assets/eip-712/eth_signTypedData.png)

EIP-712 规范包括：

- 定义好需要签名的结构体，并对结构体进行哈希。如果结构体包含嵌套结构体，则需要从内到外分别哈希
- 定义 `DOMAIN_SEPARATOR`，它需要`name`、`version`、`chainId`、`verifyContractAddress` 几个参数来生成。因为定义的结构体在不同的合约里可能是一样的，那么就会造成哈希的结果也是一样的，通过引入 `DOMAIN_SEPARATOR` 就可以对其进行区分，避免签名在其他合约内也可以使用的情况
- 前端使用 `eth_signTypedData` 对数据进行签名，如果是使用 ethersjs，可用调用 [`signer._signTypedData(domain, types, value)`](https://docs.ethers.org/v5/api/signer/#Signer-signTypedData) 进行签名
- 在合约内，可用对结构体参数进行签名，并和前端上传的签名进行校验

## 示例

在本示例里，我们将定义一个订单 `Order`，前端通过 ethersjs 签名，合约里完成对签名的校验。

### 前端代码

分别定义 `Order`、`domain`、`types`

```ts
// 定义 Oreder 结构
interface Order {
    tradeNo: number
    totalPay: number
    buyer: string
}

// 构造 order 数据
const order = <Order>{
    tradeNo: 2,
    totalPay: 1000,
    buyer: await owner.getAddress(),
};

// 构造 domain，要和合约内的数据保持一致
const domain = {
    name: 'Eip712 Demo',
    version: '1',
    chainId: await owner.getChainId(),
    verifyingContract: await contract.contractAddr(),
};

// 待签名结构的类型定义
const types = {
    Order: [{
        name: 'tradeNo',
        type: 'uint256'
    }, {
        name: 'totalPay',
        type: 'uint256'
    }, {
        name: 'buyer',
        type: 'address'
    }]
};
```

调用 ethersjs 中的 [`signer._signTypedData`](https://docs.ethers.org/v5/api/signer/#Signer-signTypedData) 方法完成数据签名，也可以使用 `web3`、`metamask` 等进行签名

```ts
const signature = await owner._signTypedData(domain, types, order);
```

调用合约的 `verify` 方法，上传原始数据和签名，进行验证

```ts
const isMatch = await contract.verify(order, signature);
```

### 合约代码

定义 `Order`、`DOMAIN_SEPARATOR` 等

```Solidity
// 定义 Order
struct Order {
        uint256 tradeNo;
        uint256 totalPay;
        address buyer;
    }

// 定义 name, version，用来生成 DOMAIN_SEPARATOR
string public constant name = "Eip712 Demo";
string public constant version = "1";

bytes32 constant ORDER_TYPEHASH =
        keccak256("Order(uint256 tradeNo,uint256 totalPay,address buyer)");
bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

bytes32 private DOMAIN_SEPARATOR;

constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(this)
            )
        );
    }
```

对结构体数据进行哈希

```Solidity
function hashOrder(Order memory order_) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    order_.tradeNo,
                    order_.totalPay,
                    order_.buyer
                )
            );
    }
```

提供 `verify` 方法，验证用户的签名

```Solidity
function verify(Order memory order_, bytes memory signature) public view returns (bool) {
        // 对原始数据签名
        bytes32 digest = keccak256(abi.encodePacked(
            '\x19\x01',
            DOMAIN_SEPARATOR,
            hashOrder(order_)
        ));

        // 从用户的签名中，提取 v, r, s
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // ecrecover(digest, v, r, s) 可用还原出签名者的地址，判断还原的地址和调用者的地址，是否一致
        return ecrecover(digest, v, r, s) == msg.sender;
    }
```

## 总结

通过使用 EIP-712 结构化类型数据签名，用户在签名的时候就可以知道所签名的内容是什么，对用户更加友好。