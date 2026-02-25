// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStaffRegistry {
    enum StaffType {
        NONE,
        TEACHER,
        NON_TEACHING
    }

    enum StaffStatus {
        NONE,
        ACTIVE,
        SUSPENDED,
        REMOVED
    }

    struct Staff {
        uint256 staffId;
        StaffType staffType;
        string fullName;
        string metadataURI;
        StaffStatus status;
        uint64 createdAt;
        uint64 updatedAt;
    }

    event StaffCreated(
        address indexed staffAccount,
        uint256 indexed staffId,
        StaffType staffType,
        string fullName,
        address indexed createdBy
    );
    event StaffUpdated(
        address indexed staffAccount,
        StaffType staffType,
        string fullName,
        string metadataURI,
        address indexed updatedBy
    );
    event StaffSuspended(address indexed staffAccount, address indexed suspendedBy);
    event StaffUnsuspended(address indexed staffAccount, address indexed unsuspendedBy);
    event StaffRemoved(address indexed staffAccount, address indexed removedBy);

    function createStaff(
        address staffAccount,
        uint256 staffId,
        StaffType staffType,
        string calldata fullName,
        string calldata metadataURI
    ) external;

    function updateStaff(
        address staffAccount,
        StaffType staffType,
        string calldata fullName,
        string calldata metadataURI
    ) external;

    function suspendStaff(address staffAccount) external;
    function unsuspendStaff(address staffAccount) external;
    function removeStaff(address staffAccount) external;

    function getStaff(address staffAccount) external view returns (Staff memory);
    function staffExists(address staffAccount) external view returns (bool);
}
