// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/escrow/ConditionalEscrow.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./NFTBargain.sol";

/**
 * 修改 openzeppelin close 方法
 * 原方法只能在 _state 为 Active 情况下才能关闭，导致开启了 Refund 之后无法 Close
 * 而且因为 _state 是 private，无法继承来修改
 */
contract RefundEscrow is ConditionalEscrow {
    using Address for address payable;

    enum State {
        Active,
        Refunding,
        Closed
    }

    event RefundsClosed();
    event RefundsEnabled();

    State private _state;
    address payable private immutable _beneficiary;

    /**
     * @dev Constructor.
     * @param beneficiary_ The beneficiary of the deposits.
     */
    constructor(address payable beneficiary_) {
        require(beneficiary_ != address(0), "RefundEscrow: beneficiary is the zero address");
        _beneficiary = beneficiary_;
        _state = State.Active;
    }

    /**
     * @return The current state of the escrow.
     */
    function state() public view virtual returns (State) {
        return _state;
    }

    /**
     * @return The beneficiary of the escrow.
     */
    function beneficiary() public view virtual returns (address payable) {
        return _beneficiary;
    }

    /**
     * @dev Stores funds that may later be refunded.
     * @param refundee The address funds will be sent to if a refund occurs.
     */
    function deposit(address refundee) public payable virtual override {
        require(state() == State.Active, "RefundEscrow: can only deposit while active");
        super.deposit(refundee);
    }

    /**
     * @dev Allows for the beneficiary to withdraw their funds, rejecting
     * further deposits.
     * 将 `_state == State.Active` 修改为 `_state == State.Active || _state == State.Refunding`
     */
    function close() public virtual onlyOwner {
        require(_state == State.Active || _state == State.Refunding, "RefundEscrow: can only close while active or refunding");
        _state = State.Closed;
        emit RefundsClosed();
    }

    /**
     * @dev Allows for refunds to take place, rejecting further deposits.
     */
    function enableRefunds() public virtual onlyOwner {
        require(state() == State.Active, "RefundEscrow: can only enable refunds while active");
        _state = State.Refunding;
        emit RefundsEnabled();
    }

    /**
     * @dev Withdraws the beneficiary's funds.
     */
    function beneficiaryWithdraw() public virtual {
        require(state() == State.Closed, "RefundEscrow: beneficiary can only withdraw while closed");
        beneficiary().sendValue(address(this).balance);
    }

    /**
     * @dev Returns whether refundees can withdraw their deposits (be refunded). The overridden function receives a
     * 'payee' argument, but we ignore it here since the condition is global, not per-payee.
     */
    function withdrawalAllowed(address) public view override returns (bool) {
        return state() == State.Refunding;
    }
}

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
    function finishAllocate() public onlyOwner {
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