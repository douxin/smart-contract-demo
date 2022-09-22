// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ETHRefundEscrow.sol";
import "./ERC20RefundEscrow.sol";

interface IABCToken {
    function balanceOf(address account) external view returns (uint256);
}

interface INFTBargain {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract Reward is Ownable {
    // address of deployed NFTBargain contract
    address constant NFT_BARGAIN_ADDRESS = 0x9d83e140330758a8fFD07F8Bd73e86ebcA8a5692;

    // address of deployed ABCToken contract
    address constant ABC_TOKEN_ADDRESS = 0x9d83e140330758a8fFD07F8Bd73e86ebcA8a5692;

    using SafeMath for uint256;

    ETHRefundEscrow private immutable _refundEscrow;
    ERC20RefundEscrow private immutable _erc20RefundEscrow;

    // NFT mint 数量
    uint256 private _mintedCount;

    enum RewardState {
        MintIsActive, // mint 正在进行中，此时不可操作
        RewardAllocating, // 正在分配奖金
        CanWithdraw, // 用户取现阶段
        Finished // 取现结束，管理员可以取回剩余奖金
    }

    RewardState private _rewardState;

    constructor() payable {
        _rewardState = RewardState.MintIsActive;
        _mintedCount = 0;
        _refundEscrow = new ETHRefundEscrow(payable(msg.sender));
        _erc20RefundEscrow = new ERC20RefundEscrow(payable(msg.sender));
    }

    /**
     * 获取奖池总金额
     */
    function totalRewards() public view returns (uint256) {
        return address(this).balance;
    }

    function totalABCRewards() public view returns (uint256) {
        return IABCToken(ABC_TOKEN_ADDRESS).balanceOf(address(this));
    }

    /**
     * 追加奖金，仅在还在 mint 阶段才能追加
     */
    function appendRewardAmount() public payable onlyOwner {
        require(_rewardState == RewardState.MintIsActive, "only append when mint is active");
        require(msg.value > 0, "value should greater than 0");
        payable(address(this)).transfer(msg.value);
    }

    function _nftMintedNum() internal view returns (uint256) {
        // return NFTBargain(payable(NFT_BARGAIN_ADDRESS)).getMintedNumer();
        return _mintedCount;
    }

    function _ownerOfToken(uint256 tokenId) internal view returns (address) {
        return INFTBargain(NFT_BARGAIN_ADDRESS).ownerOf(tokenId);
    }

    modifier canAllocate() {
        require(_rewardState == RewardState.RewardAllocating, "state is not allocating");
        _;
    }

    modifier canWithdraw() {
        require(_rewardState == RewardState.CanWithdraw, "reward is allocating");
        _;
    }

    /**
     * mint 完成
     */
    function finishMint(uint256 mintedCount) public onlyOwner {
        _rewardState = RewardState.RewardAllocating;
        _mintedCount = mintedCount;
    }

    /**
     * 奖金分配已完成
     */
    function finishAllocate() public onlyOwner {
        _rewardState = RewardState.CanWithdraw;
        // 开启托管兑换
        _refundEscrow.enableRefunds();
        _erc20RefundEscrow.enableRefunds();
    }

    /**
     * 取现结束
     */
    function finishWithdraw() public onlyOwner {
        _rewardState = RewardState.Finished;
        _refundEscrow.close();
        _erc20RefundEscrow.close();
    }

    /**
     * 获取平均金额
     * avgAmount = 奖池总金额 / NFT minted 数量
     */
    function _getAverageRewardAmount(uint256 mintedNum) internal view onlyOwner canAllocate returns (uint256) {
        uint256 rewards = totalRewards();
        require(rewards > 0, "rewards should larger than 0");
        return rewards.div(mintedNum);
    }

    function _getAverageABCRewardAmount(uint256 mintedNum) internal view onlyOwner canAllocate returns (uint256) {
        uint256 rewards = totalABCRewards();
        require(rewards > 0, "rewards should larger than 0");
        return rewards.div(mintedNum);
    }

    /**
     * 管理员调用，给用户分配奖金
     */
    function allocateReward() public onlyOwner canAllocate {
        uint256 curMintedNum = _nftMintedNum();
        require(curMintedNum > 0, "minted number should greater than 0");

        uint256 rewardAmount = _getAverageRewardAmount(curMintedNum);
        uint256 abcRewardAmount = _getAverageABCRewardAmount(curMintedNum);

        for (uint256 i = 0; i < curMintedNum; i++) {
            address user = _ownerOfToken(i);
            _refundEscrow.deposit{value: rewardAmount}(user);
            _erc20RefundEscrow.deposit(user, abcRewardAmount);
        }
    }

    /**
     * 用户调用，查询可以取现的金额
     */
    function queryMyReward() public view canWithdraw returns (uint256, uint256) {
        uint256 ethAmount = _refundEscrow.depositsOf(msg.sender);
        uint256 abcAmount = _erc20RefundEscrow.depositsOf(msg.sender);
        return (ethAmount, abcAmount);
    }

    /**
     * 用户调用，取现奖金
     */
    function withdrawReward() public canWithdraw {
        _refundEscrow.withdraw(payable(msg.sender));
        _erc20RefundEscrow.withdraw(payable(msg.sender));
    }

    /**
     * 管理员取回剩余奖金
     */
    function withdrawRest() public onlyOwner {
        _refundEscrow.beneficiaryWithdraw();
        _erc20RefundEscrow.beneficiaryWithdraw();
    }

    event ETHReceive(address, uint256);

    receive() external payable {
        emit ETHReceive(msg.sender, msg.value);
    }
}