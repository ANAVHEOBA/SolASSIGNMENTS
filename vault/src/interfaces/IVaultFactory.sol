// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVaultFactory {
    event VaultCreated(
        address indexed token,
        address indexed vault,
        bytes32 indexed salt,
        uint256 nftTokenId
    );
    event Deposited(address indexed token, address indexed vault, address indexed user, uint256 amount);

    error InvalidToken();
    error InvalidAmount();
    error VaultAlreadyExists();


    //to get the place where the token was put in the token address is passed and what being returned is the address of the vault
    function vaultOfToken(address token) external view returns (address vault);

    //pass in the token address and the deterministic address is returned using the CREATE2 formula
    function predictVaultAddress(address token) external view returns (address predicted);
    // the function to deposit the token and amount and what is being returned is the vault address
    function deposit(address token, uint256 amount) external returns (address vault);
}
