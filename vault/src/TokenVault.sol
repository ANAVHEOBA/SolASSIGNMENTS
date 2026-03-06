// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITokenVault} from "./interfaces/ITokenVault.sol";

contract TokenVault is ITokenVault {
    address public immutable override asset;
    address public immutable override factory;

    mapping(address => uint256) public override balanceOf;
    uint256 public override totalDeposited;

    constructor(address asset_, address factory_) {
        asset = asset_;
        factory = factory_;
    }

    function recordDeposit(address user, uint256 amount) external override {
        if (msg.sender != factory) revert NotFactory();
        if (amount == 0) revert InvalidAmount();

        balanceOf[user] += amount;
        totalDeposited += amount;
        emit Deposited(user, amount);
    }
}
