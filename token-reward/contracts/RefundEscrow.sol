// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract RefundEscrow is Ownable {
    event Deposited(address indexed payee, uint256 weiAmount);
    event Withdrawn(address indexed payee, uint256 weiAmount);

    mapping(address => uint256) private _deposits;

    enum State {
        Active,
        Refunding,
        Closed
    }

    State private _state;
    address payable private immutable _beneficiary;

    constructor(address payable beneficiary_) {
        require(beneficiary_ != address(0), "RefundEscrow: beneficiary is the zero address");
        _beneficiary = beneficiary_;
        _state = State.Active;
    }

    function state() public view returns (State) {
        return _state;
    }

    function beneficiary() public view returns (address payable) {
        return _beneficiary;
    }

    function depositsOf(address payee) public view returns (uint256) {
        return _deposits[payee];
    }

    function close() public virtual onlyOwner {
        require(_state == State.Active || _state == State.Refunding, "RefundEscrow: can only close while active or refunding");
        _state = State.Closed;
    }

    function enableRefunds() public virtual onlyOwner {
        require(_state == State.Active, "RefundEscrow: can only enable refunds while active");
        _state = State.Refunding;
    }

    function emptyDeposit(address payee) public onlyOwner {
        _deposits[payee] = 0;
    }

    function deposit(address payee, uint256 amount) public payable virtual onlyOwner {
        require(state() == State.Active, "RefundEscrow: can only deposit while active");
        _deposits[payee] += amount;
    }

    function withdraw(address payable payee) public virtual;
    function beneficiaryWithdraw() public virtual;
}