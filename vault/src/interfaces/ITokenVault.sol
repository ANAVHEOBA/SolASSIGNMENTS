// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenVault {
    event Deposited(address indexed user, uint256 amount);

    error InvalidAmount();
    error NotFactory();
    

    //the erc20 token that is to be deposited into the vault
    function asset() external view returns (address);

    // stored factory address so that anyone can check "which factory controls this vault"
    function factory() external view returns (address);

    // the amount of erc20 token that was deposited
    function totalDeposited() external view returns (uint256);
    // the functon that shows the user balance when the address of the user is passed and it returns a value
    function balanceOf(address user) external view returns (uint256);


    // the function used to record the deposit something like a receipt being generated
    function recordDeposit(address user, uint256 amount) external;
}
