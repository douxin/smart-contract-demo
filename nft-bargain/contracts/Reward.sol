// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/escrow/RefundEscrow.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./NFTBargain.sol";

contract Reward is Ownable {
    // address of deployed NFT contract
    address constant NFT_BARGAIN_ADDRESS = 0x9d83e140330758a8fFD07F8Bd73e86ebcA8a5692;
    using SafeMath for uint256;

    RefundEscrow private immutable _refundEscrow;

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
        _refundEscrow = new RefundEscrow(payable(msg.sender));
    }

    /**
     * 获取奖池总金额
     */
    function totalRewards() public view returns (uint256) {
        return address(this).balance;
    }

    function _nftMintedNum() internal view returns (uint256) {
        // return NFTBargain(payable(NFT_BARGAIN_ADDRESS)).getMintedNumer();
        return _mintedCount;
    }

    function _ownerOfToken(uint256 tokenId) internal view returns (address) {
        return NFTBargain(payable(NFT_BARGAIN_ADDRESS)).ownerOf(tokenId);
    }

    modifier canAllocate() {
        require(_rewardState == RewardState.RewardAllocating, "mint is not finish");
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
    function finishRewardAllocate() public onlyOwner {
        _rewardState = RewardState.CanWithdraw;
        // 开启托管兑换
        _refundEscrow.enableRefunds();
    }

    /**
     * 取现结束
     */
    function finishWithdraw() public onlyOwner {
        _rewardState = RewardState.Finished;
        _refundEscrow.close();
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

    /**
     * 管理员调用，给用户分配奖金
     */
    function allocateReward() public onlyOwner canAllocate {
        uint256 curMintedNum = _nftMintedNum();
        require(curMintedNum > 0, "minted number should greater than 0");

        uint256 rewardAmount = _getAverageRewardAmount(curMintedNum);
        for (uint256 i = 0; i < curMintedNum; i++) {
            address user = _ownerOfToken(i);
            _refundEscrow.deposit{value: rewardAmount}(user);
        }
    }

    /**
     * 用户调研，查询可以取现的金额
     */
    function queryMyReward() public view canWithdraw returns (uint256) {
        return _refundEscrow.depositsOf(msg.sender);
    }

    /**
     * 用户调用，取现奖金
     */
    function withdrawReward() public canWithdraw {
        _refundEscrow.withdraw(payable(msg.sender));
    }

    /**
     * 管理员取回剩余奖金
     */
    function withdrawRest() public onlyOwner {
        _refundEscrow.beneficiaryWithdraw();
    }

    event ETHReceive(address, uint256);

    receive() external payable {
        emit ETHReceive(msg.sender, msg.value);
    }
}