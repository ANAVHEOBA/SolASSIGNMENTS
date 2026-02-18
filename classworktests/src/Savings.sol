// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}




contract Savings {
    mapping(address => uint256) public etherBalance;
    mapping(address => mapping(address => uint256)) public tokenBalance;

    function depositEther() external payable {
        require(msg.value > 0, "Amount must be greater than 0");
        etherBalance[msg.sender] += msg.value;
    }

    function depositToken(address token, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        tokenBalance[msg.sender][token] += amount;
    }

    function getEtherBalance(address user) external view returns (uint256) {
        return etherBalance[user];
    }

    function getTokenBalance(address user, address token) external view returns (uint256) {
        return tokenBalance[user][token];
    }

    function withdrawEther(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(etherBalance[msg.sender] >= amount, "Insufficient balance");
        etherBalance[msg.sender] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function withdrawToken(address token, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(tokenBalance[msg.sender][token] >= amount, "Insufficient balance");
        tokenBalance[msg.sender][token] -= amount;
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");
    }

    receive() external payable {
        etherBalance[msg.sender] += msg.value;
    }
}
