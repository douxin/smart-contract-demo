# NFT Bargain
NFT 砍一刀项目，类似于拼夕夕的砍一刀功能。目前大部分的 NFT 采用的白名单机制来增强社区的活跃度，鼓励大家拉新。砍一刀也是类似的目的，邀请好友打开活动主页也是拉新。

在部署合约的时候，可以设定成团的人数，当用户邀请好友的人数达到要求时，该用户才具备 mint 的能力。

## Project structure
```
├── README.md
├── contracts // 合约代码
├── hardhat.config.ts
├── package-lock.json
├── package.json
├── scripts // 合约部署脚本
├── test // 合约测试代码
├── tsconfig.json
```

## 合约
共 3 个合约，`Activity.sol` 是活动合约，`NFTBargain.sol` 是 NFT 合约，`Reward` 是奖池合约。

活动进行中，只要满足了助力条件，就可以 mint NFT。在活动结束后，所有 NFT 持有者可以平分奖池内的金额。在奖金兑换完成后，剩余未被领取的金额将被管理员取回。

## 助力要求
必须满足以下条件才能成功“砍一刀”：
- 活动必须已开始且未结束
- 不能给自己助力
- 只能给目标用户助力一次，不可重复

当满足以上所有条件后，可以通过 `bargainFor` 来助力。

当上述条件均满足后，可以通过 `mint` 方法完成 NFT mint。当成功 mint 后，用户的已助力次数会清零。

## 防刷机制
为了防止用户刷单，增加了两个限制条件。分别为：
- 单个用户只能为他人助力 `MAX_BARGAIN_FOR_COUNT` 次
- 每个用户最多只能 mint `MAX_MINT_NUM_PER_ADDRESS` 个 NFT

## 如何设置 tokenURI
`tokenURI` 是一个 json 文件，其中包含该 token 的 metadata。此文件可以存放在去中心化的存储上，如 `IPFS`。`tokenURI` 地址格式如 `https://ipfs.io/ipfs/QmQoJjiFkEaQ1oaetbDFEXKqwjwWCCvMSBiDU1x196JjYP?filename=0`，最后的 `0` 是 `tokenId`，前面是 `baseTokenURI`，在部署合约的时候设定。

可以将助力的次数添加到 token metadata 中，调用 `mint` 方法可以返回此次 `tokenId`、`latestBargainedNum`(此次 mint 周期的助力次数)，在 json 文件中增加：

```json
{
    "image": "ipfs://IMAGE_CID",
    "name": "token name",
    "description": "token desc",
    "attributes": [
        {
            "trait_type": "Bargain Number",
            "display_type": "number",
            "value": "${latestBargainedNum}"
        }
    ]
}
```

此 json 文件中的各项属性含义见 👉 [OpenSea Metadata Standards](https://docs.opensea.io/docs/metadata-standards)

## 如何动态生成 NFT 图片
在项目的 `common-utils` 中有动态生成图片的脚本。在 `mint` 之后，会得到 `tokenId`、`助力人数` 等信息，可以将这些信息通过脚本自动生成图片，并上传至 `ipfs` 得到图片 `CID`。

然后组合信息的到最终的 json 文件，并使用 `tokenId` 命名上传至 `ipfs` 即可。在上传时要确保文件的访问路径和对应的 `tokenURI` 是一致的。

## 奖金池
项目增加了奖池功能，支持 ETH 和 ERC20。对于 ETH 可以在部署奖励合约 `Reward` 时转入，对于 ERC20，可以在 `ABCToken` 部署后，调用 `transfer` 转入。

`ETHRefundEscrow` 和 `ERC20RefundEscrow` 继承自 `RefundEscrow`，实现了三方托管奖金。在用户兑换奖金后，剩余的资产由管理员调用 `withdrawRest` 取回。