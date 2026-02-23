// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPropertyManagement {
    struct Property {
        uint256 id;
        string title;
        string location;
        string description;
        uint256 price;
        address seller;
        bool isActive;
    }

    function createProperty(
        uint256 id,
        string calldata title,
        string calldata location,
        string calldata description,
        uint256 price
    ) external;

    function removeProperty(uint256 id) external;

    function getAllProperties() external view returns (Property[] memory);

    function buyProperty(uint256 id) external;
}
