# EIP-2612: Permit Extension for EIP-20 Signed Approvals

## 背景

EIP-20 定义了 `token` 相关规范和接口，但是 `approve` 方法在设计上，必须由 EOA 账户发起请求，这使得一个转账的操作也必须要有两次授权才行。即用户首先 `approve`，然后在调用 `transferFrom` 来完成。同时，如果 Alice 的钱包内没有多余的费用来支持 Gas，他没没办法让 Bob 代替自己来发起请求。

## 解决方案

[EIP-2612](https://eips.ethereum.org/EIPS/eip-2612) 给 [EIP-20](https://eips.ethereum.org/EIPS/eip-20) 增加了名为 `Permit` 的扩展授权标准。通过使用该授权方法，Alice 可以将签名发给 Bob，Bob 可以代替 Alice 完成请求。

EIP-2612 是在 EIP-712 基础上完成的，它使用了 EIP-712 的方法，对 EIP-712 不熟悉的读者，可以阅读我们[对应的教程](https://github.com/douxin/smart-contract-demo/tree/main/eip712-demo)。

## 规范

EIP-2612 定义了三个方法，分别为：

```Solidity

    // 授权方法
    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    // 返回 nonce，内部为自增长 uint256
    function nonces(address owner) external view returns (uint);

    // 返回 DOMAIN_SEPARATOR，详见 EIP-712 教程介绍
    function DOMAIN_SEPARATOR() external view returns (bytes32);
```

## 使用

### 前端代码

```ts
            // 构造签名数据
            const permit = {
                owner: await alice.getAddress(),
                spender: contract.address,
                value: ethers.BigNumber.from("10"),
                nonce: await contract.nonces(await alice.getAddress()),
                deadline: 1672329600 // 2022-12-30
            };

            // domain
            const domain = {
                name: 'Eip2612 Demo',
                version: '1',
                chainId: await owner.getChainId(),
                verifyingContract: contract.address
            };

            // permit type
            const types = {
                "Permit": [{
                    "name": "owner",
                    "type": "address"
                },
                {
                    "name": "spender",
                    "type": "address"
                },
                {
                    "name": "value",
                    "type": "uint256"
                },
                {
                    "name": "nonce",
                    "type": "uint256"
                },
                {
                    "name": "deadline",
                    "type": "uint256"
                }
                ]
            };

            // 生成签名
            const signature = await alice._signTypedData(domain, types, permit);

            // 调用合约业务方法，transferWithPermit 方法内部会调用自身的 permit 方法来完成签名的校验
            await contract.connect(bob).transferWithPermit(permit.owner, permit.spender, permit.value, permit.deadline, signature)
```

### 合约代码

```Solidity

    // 前端调用的业务接口
    function transferWithPermit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        bytes memory signature
    ) external {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // 调用 permit
        return permit(owner, spender, value, deadline, v, r, s);
    }

    // permit 的具体实现，详细介绍可见 EIP-712 教程
    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override {
        // 生成 permit hash
        bytes32 hashedPermit = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonceOf(owner),
                deadline
            )
        );

        // 生成签名
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR_, hashedPermit)
        );

        // 还原签名者地址
        address signer = ecrecover(digest, v, r, s);

        // 校验地址
        require(signer == owner, "Invalid Signature");

        // 调用 EIP-20 的 _approve
        _approve(owner, spender, value);
    }

    // 返回 nonce，内部使用 Counters.Counter 实现
    function nonces(address owner) external view override returns (uint) {
        return nonces_[owner].current();
    }

    // 返回 DOMAIN_SEPARATOR
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return DOMAIN_SEPARATOR_;
    }
```

## 测试

运行 `npx hardhat test` 可以运行测试用例

## 总结

EIP-2612 是使用了 EIP-712 的签名方法，用来扩展 EIP-20 的授权方法，使用此方法，可以实现链下签名，并由他人代替发起请求。
