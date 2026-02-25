// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockERC20 {
  string public name = "Mock";
  string public symbol = "MOCK";
  uint8 public decimals = 18;

  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;

  function mint(address to, uint256 amount) external {
    balanceOf[to] += amount;
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    allowance[msg.sender][spender] = amount;
    return true;
  }

  function transfer(address to, uint256 amount) external returns (bool) {
    uint256 bal = balanceOf[msg.sender];
    require(bal >= amount, "INSUFFICIENT_BALANCE");
    balanceOf[msg.sender] = bal - amount;
    balanceOf[to] += amount;
    return true;
  }

  function transferFrom(address from, address to, uint256 amount) external returns (bool) {
    uint256 allowed = allowance[from][msg.sender];
    require(allowed >= amount, "INSUFFICIENT_ALLOWANCE");
    uint256 bal = balanceOf[from];
    require(bal >= amount, "INSUFFICIENT_BALANCE");
    allowance[from][msg.sender] = allowed - amount;
    balanceOf[from] = bal - amount;
    balanceOf[to] += amount;
    return true;
  }
}
