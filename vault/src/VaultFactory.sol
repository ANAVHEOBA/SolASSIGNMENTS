// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVaultFactory} from "./interfaces/IVaultFactory.sol";
import {IVaultNFT} from "./interfaces/IVaultNFT.sol";
import {ITokenVault} from "./interfaces/ITokenVault.sol";
import {TokenVault} from "./TokenVault.sol";
import {VaultNFT} from "./VaultNFT.sol";

interface IERC20Like {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract VaultFactory is IVaultFactory {
    address public immutable vaultNft;
    mapping(address => address) public override vaultOfToken;

    uint256 private _locked = 1;

    error TransferFailed();
    error Reentrancy();
    error BalanceReadFailed();

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor() {
        vaultNft = address(new VaultNFT("Vault Positions", "VLT", address(this)));
    }

    function deposit(address token, uint256 amount) external override nonReentrant returns (address vault) {
        if (token == address(0) || token.code.length == 0) revert InvalidToken();
        if (amount == 0) revert InvalidAmount();

        vault = vaultOfToken[token];
        if (vault == address(0)) {
            vault = _deployVault(token);
            vaultOfToken[token] = vault;
            uint256 nftTokenId = IVaultNFT(vaultNft).mintForVault(msg.sender, vault);
            emit VaultCreated(token, vault, _salt(token), nftTokenId);
        }

        uint256 beforeBal = _safeBalanceOf(token, vault);
        _safeTransferFrom(token, msg.sender, vault, amount);
        uint256 afterBal = _safeBalanceOf(token, vault);
        uint256 received = afterBal - beforeBal;
        if (received == 0) revert TransferFailed();
        ITokenVault(vault).recordDeposit(msg.sender, received);

        emit Deposited(token, vault, msg.sender, received);
    }

    function predictVaultAddress(address token) external view override returns (address predicted) {
        bytes32 salt = _salt(token);
        bytes memory bytecode = abi.encodePacked(type(TokenVault).creationCode, abi.encode(token, address(this)));
        bytes32 hash = keccak256(bytecode);

        predicted = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, hash))))
        );
    }

    function _deployVault(address token) internal returns (address vault) {
        bytes32 salt = _salt(token);
        vault = address(new TokenVault{salt: salt}(token, address(this)));
    }

    function _salt(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(token));
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory ret) =
            token.call(abi.encodeCall(IERC20Like.transferFrom, (from, to, amount)));
        if (!ok || (ret.length != 0 && !abi.decode(ret, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeBalanceOf(address token, address account) internal view returns (uint256 bal) {
        (bool ok, bytes memory ret) = token.staticcall(abi.encodeCall(IERC20Like.balanceOf, (account)));
        if (!ok || ret.length < 32) revert BalanceReadFailed();
        bal = abi.decode(ret, (uint256));
    }
}
