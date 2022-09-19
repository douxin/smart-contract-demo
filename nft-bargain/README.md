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

## Contract Source Code
合约主要是由 `IActivity`、`IBargain` 两个 `interface` 来实现的。前者控制活动的开始和结束，只有在活动开始且活动未结束的情况下，该活动才能使用，可以通过 `isActivityValid` 来获取结果。

`IBargain` 这个接口里控制着“砍一刀”的具体实现，必须满足以下条件才能成功“砍一刀”：
- 活动必须已开始且未结束
- 不能给自己助力
- 只能给目标用户助力一次，不可重复

当满足以上所有条件后，可以通过 `bargainFor` 来助力。

当上述条件均满足后，可以通过 `mint` 方法完成 NFT mint。当成功 mint 后，用户的已助力次数会清零。