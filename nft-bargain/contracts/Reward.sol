// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./NFTBargain.sol";

interface IReward {
    enum RewardState {
        NotStart, // owner allocate reward
        WithdrawActive, // user can withdraw reward
        Finished // cannot withdraw
    }

    // 管理员分配奖池
    function allocateReward() external;
}

contract Reward is Ownable, IReward, PullPayment {
    // address of deployed NFT contract
    address constant NFT_BARGAIN_ADDRESS = 0xd2FCFefFe8E79F6eFb74567403Ba45CC5eba8981;

    RewardState _rewardState;

    using SafeMath for uint256;

    constructor() {
        _rewardState = RewardState.NotStart;
    }

    // 管理员开启奖池取现
    function startRewardWithdraw() public onlyOwner {
        _rewardState = RewardState.WithdrawActive;
    }

    // 管理员关闭奖池取现
    function endRewardWithdraw() public onlyOwner {
        _rewardState = RewardState.Finished;
    }

    /**
     * 获取奖池总金额
     */
    function totalRewards() public view returns (uint256) {
        return address(this).balance;
    }

    function _nftMintedNum() internal view returns (uint256) {
        return NFTBargain(payable(NFT_BARGAIN_ADDRESS)).getMintedNumer();
    }

    function _ownerOfToken(uint256 tokenId) internal view returns (address) {
        return NFTBargain(payable(NFT_BARGAIN_ADDRESS)).getOwnerOf(tokenId);
    }

    function _isMintFinished() internal view returns (bool) {
        return NFTBargain(payable(NFT_BARGAIN_ADDRESS)).isMintFinished();
    }

    modifier rewardWithdrawShouldNotStart() {
        require(_isMintFinished(), "mint should finished");
        require(_rewardState == RewardState.NotStart, "reward should not start");
        _;
    }

    /**
     * 获取平均金额
     * avgAmount = 奖池总金额 / NFT minted 数量
     */
    function _getAverageRewardAmount(uint256 mintedNum) internal view onlyOwner rewardWithdrawShouldNotStart returns (uint256) {
        uint256 rewards = totalRewards();
        require(rewards > 0, "rewards should larger than 0");
        return rewards.div(mintedNum);
    }

    /**
     * 管理员调用，给用户分配奖金
     */
    function allocateReward() public onlyOwner rewardWithdrawShouldNotStart {
        uint256 curMintedNum = _nftMintedNum();
        require(curMintedNum > 0, "minted number should greater than 0");

        uint256 rewardAmount = _getAverageRewardAmount(curMintedNum);
        for (uint256 i = 0; i < curMintedNum; i++) {
            address user = _ownerOfToken(i);
            _asyncTransfer(user, rewardAmount);
        }
    }

    /**
     * 用户调用，取现奖金
     */
    function withdrawPayments(address payable payee) public override {
        require(_rewardState == RewardState.WithdrawActive, "withdraw should active");
        require(msg.sender == payee, "only withdraw for self");
        super.withdrawPayments(payee);
    }
}
