// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVaultNFT} from "./interfaces/IVaultNFT.sol";
import {ITokenVault} from "./interfaces/ITokenVault.sol";
import {Base64} from "./utils/Base64.sol";
import {StringUtil} from "./utils/StringUtil.sol";

interface IERC20MetadataLike {
    function symbol() external view returns (string memory);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

contract VaultNFT is IVaultNFT {
    string public name;
    string public symbol;
    address public immutable factory;

    uint256 public nextTokenId = 1;

    mapping(uint256 => address) public override vaultById;
    mapping(address => uint256) public override idByVault;

    mapping(uint256 => address) private _ownerOf;
    mapping(address => uint256) private _balanceOf;
    mapping(uint256 => address) private _approvals;
    mapping(address => mapping(address => bool)) private _isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    error NotAuthorized();
    error InvalidReceiver();
    error InvalidOwner();
    error InvalidSpender();
    error TokenDoesNotExist();

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotAuthorized();
        _;
    }

    constructor(string memory name_, string memory symbol_, address factory_) {
        name = name_;
        symbol = symbol_;
        factory = factory_;
    }

    function mintForVault(address to, address vault) external override onlyFactory returns (uint256 tokenId) {
        if (idByVault[vault] != 0) revert AlreadyMintedForVault();

        tokenId = nextTokenId++;
        idByVault[vault] = tokenId;
        vaultById[tokenId] = vault;
        _mint(to, tokenId);

        emit VaultNftMinted(tokenId, vault, to);
    }

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert InvalidOwner();
        return _balanceOf[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert TokenDoesNotExist();
        return owner;
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        ownerOf(tokenId);
        return _approvals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return _isApprovedForAll[owner][operator];
    }

    function approve(address spender, uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !_isApprovedForAll[owner][msg.sender]) revert NotAuthorized();
        _approvals[tokenId] = spender;
        emit Approval(owner, spender, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        if (operator == address(0)) revert InvalidSpender();
        _isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (to == address(0)) revert InvalidReceiver();
        address owner = ownerOf(tokenId);
        if (owner != from) revert InvalidOwner();
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotAuthorized();

        delete _approvals[tokenId];
        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }
        _ownerOf[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        transferFrom(from, to, tokenId);
        if (to.code.length != 0) {
            bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data);
            if (retval != IERC721Receiver.onERC721Received.selector) revert InvalidReceiver();
        }
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        address vault = vaultById[tokenId];
        if (vault == address(0)) revert TokenDoesNotExist();

        address asset = ITokenVault(vault).asset();
        uint256 total = ITokenVault(vault).totalDeposited();

        string memory tokenSymbol = _safeSymbol(asset);
        string memory vaultAddr = StringUtil.toHexAddress(vault);
        string memory assetAddr = StringUtil.toHexAddress(asset);
        string memory totalStr = StringUtil.toString(total);
        string memory idStr = StringUtil.toString(tokenId);

        string memory svg = string(
            abi.encodePacked(
                "<svg xmlns='http://www.w3.org/2000/svg' width='800' height='420'>",
                "<defs><linearGradient id='g' x1='0' x2='1'><stop offset='0%' stop-color='#0f172a'/>",
                "<stop offset='100%' stop-color='#1e293b'/></linearGradient></defs>",
                "<rect width='100%' height='100%' fill='url(#g)'/>",
                "<text x='40' y='70' fill='#e2e8f0' font-size='36' font-family='monospace'>Vault Position #",
                idStr,
                "</text><text x='40' y='135' fill='#38bdf8' font-size='28' font-family='monospace'>Token: ",
                tokenSymbol,
                "</text><text x='40' y='185' fill='#cbd5e1' font-size='20' font-family='monospace'>Asset: ",
                assetAddr,
                "</text><text x='40' y='235' fill='#cbd5e1' font-size='20' font-family='monospace'>Vault: ",
                vaultAddr,
                "</text><text x='40' y='285' fill='#86efac' font-size='24' font-family='monospace'>Total Deposited: ",
                totalStr,
                "</text></svg>"
            )
        );

        string memory image = string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(bytes(svg))));
        string memory json = string(
            abi.encodePacked(
                '{"name":"Vault Position #',
                idStr,
                '","description":"Onchain NFT for token vault","attributes":[',
                '{"trait_type":"token_symbol","value":"',
                tokenSymbol,
                '"},{"trait_type":"asset","value":"',
                assetAddr,
                '"},{"trait_type":"vault","value":"',
                vaultAddr,
                '"},{"trait_type":"total_deposited","value":"',
                totalStr,
                '"}],"image":"',
                image,
                '"}'
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == 0x80ac58cd || interfaceId == 0x5b5e139f;
    }

    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert InvalidReceiver();
        _ownerOf[tokenId] = to;
        unchecked {
            _balanceOf[to]++;
        }
        emit Transfer(address(0), to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return spender == owner || _approvals[tokenId] == spender || _isApprovedForAll[owner][spender];
    }

    function _safeSymbol(address asset) internal view returns (string memory) {
        (bool ok, bytes memory ret) = asset.staticcall(abi.encodeCall(IERC20MetadataLike.symbol, ()));
        if (!ok || ret.length == 0) return "UNKNOWN";
        if (ret.length == 32) {
            bytes32 data = abi.decode(ret, (bytes32));
            return _bytes32ToString(data);
        }
        if (ret.length < 64) return "UNKNOWN";

        uint256 offset;
        uint256 strlen;
        assembly {
            offset := mload(add(ret, 32))
            strlen := mload(add(ret, 64))
        }
        if (offset != 32 || ret.length < 64 + strlen) return "UNKNOWN";

        return abi.decode(ret, (string));
    }

    function _bytes32ToString(bytes32 data) internal pure returns (string memory) {
        uint256 len;
        while (len < 32 && data[len] != 0) {
            unchecked {
                ++len;
            }
        }
        if (len == 0) return "UNKNOWN";

        bytes memory out = new bytes(len);
        for (uint256 i = 0; i < len; ++i) {
            out[i] = data[i];
        }
        return string(out);
    }
}
