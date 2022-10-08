# Token Reward
奖金池项目，在 NFT mint 结束后，所有持有者可以平分奖池。奖池内剩余的资金退回管理员。奖金池支持 `ETH` 和 `ERC20 token`。

对于 ETH 可以在部署奖励合约 `Reward` 时转入，对于 ERC20，可以在 `ABCToken` 部署后，调用 `transfer` 转入。

`ETHRefundEscrow` 和 `ERC20RefundEscrow` 继承自 `RefundEscrow`，实现了三方托管奖金。在用户兑换奖金后，剩余的资产由管理员调用 `withdrawRest` 取回。