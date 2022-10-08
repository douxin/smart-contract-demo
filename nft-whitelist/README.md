# NFT 白名单功能

使用 `Merkle Tree` 实现 NFT 白名单功能，优点是链上无需存储白名单地址，可以大幅减少 `Gas` 消耗。本合约仅实现白名单部分功能，未实现 `NFT` 相关接口。`NFT` 的实现可以参考 `nft-bargain` 项目代码。

## 流程
### 合约
在合约里，使用 `openzeppelin` 的 `MerkleProof` 进行验证。它需要 `root` 和 `proof` 两个参数。`root` 是 `merkle tree` 的 `root`，在前端生成，并调用合约的 `setRoot` 方法进行设置。

`proof` 是在前端通过目标用户的地址生成的。

### 前端
使用白名单内的地址列表构造 `merkle tree`，生成 `root`，并设置到合约里。在每次 `mint` 的时候，使用 `merkle tree` 生成目标用户的 `proof` 来调用合约接口。前端的具体使用见 `test/Whitelist.ts`。