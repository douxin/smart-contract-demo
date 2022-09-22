// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/escrow/ConditionalEscrow.sol";

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