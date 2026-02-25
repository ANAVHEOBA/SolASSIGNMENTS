// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Receiver {
  uint256 public count;
  uint256 public lastValue;

  event Ping(uint256 indexed n, uint256 value);

  function ping(uint256 n) external payable {
    count = n;
    lastValue = msg.value;
    emit Ping(n, msg.value);
  }
}
