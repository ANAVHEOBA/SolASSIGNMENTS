// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IPropertyManagement} from "./IPropertyManagement.sol";

contract PropertyManagement is AccessControl, IPropertyManagement {
    ERC20 public immutable paymentToken;
    mapping(uint256 => Property) private propertiesById;
    uint256[] private propertyIds;
    mapping(address => bool) public admins;
    mapping(address => bool) public sellers;
    mapping(address => bool) public buyers;

    modifier onlyAdmin() {
        require(admins[msg.sender], "not admin");
        _;
    }

    modifier onlySeller() {
        require(sellers[msg.sender], "not seller");
        _;
    }

    modifier onlyBuyer() {
        require(buyers[msg.sender], "not buyer");
        _;
    }

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "zero token");
        paymentToken = ERC20(tokenAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        admins[msg.sender] = true;
        sellers[msg.sender] = true;
        buyers[msg.sender] = true;
    }

    function setAdmin(address account, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        admins[account] = allowed;
    }

    function setSeller(address account, bool allowed) external onlyAdmin {
        sellers[account] = allowed;
    }

    function setBuyer(address account, bool allowed) external onlyAdmin {
        buyers[account] = allowed;
    }

    function createProperty(
        uint256 id,
        string calldata title,
        string calldata location,
        string calldata description,
        uint256 price
    ) external onlySeller {
        require(price > 0, "zero price");
        require(propertiesById[id].seller == address(0), "exists");

        propertiesById[id] = Property({
            id: id,
            title: title,
            location: location,
            description: description,
            price: price,
            seller: msg.sender,
            isActive: true
        });
        propertyIds.push(id);
    }

    function removeProperty(uint256 id) external onlyAdmin {
        require(propertiesById[id].seller != address(0), "not found");
        propertiesById[id].isActive = false;
    }

    function getAllProperties() external view returns (Property[] memory) {
        Property[] memory items = new Property[](propertyIds.length);
        for (uint256 i = 0; i < propertyIds.length; i++) {
            items[i] = propertiesById[propertyIds[i]];
        }
        return items;
    }

    function buyProperty(uint256 id) external onlyBuyer {
        Property storage property = propertiesById[id];
        require(property.seller != address(0), "not found");
        require(property.isActive, "inactive");

        property.isActive = false;
        bool ok = paymentToken.transferFrom(msg.sender, property.seller, property.price);
        require(ok, "pay failed");
    }
}
