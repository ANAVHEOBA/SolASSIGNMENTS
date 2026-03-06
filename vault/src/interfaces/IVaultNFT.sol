// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVaultNFT {
    event VaultNftMinted(uint256 indexed tokenId, address indexed vault, address indexed to);

    error AlreadyMintedForVault();


    // when one want to mint an nft from a particular vault and the address that receiving the nft the tokenId of the nft is returned
    function mintForVault(address to, address vault) external returns (uint256 tokenId);
    function idByVault(address vault) external view returns (uint256);
    function vaultById(uint256 tokenId) external view returns (address);
}
