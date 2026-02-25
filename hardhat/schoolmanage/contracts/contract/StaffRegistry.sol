// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISchoolRoles} from "../interfaces/ISchoolRoles.sol";
import {IStaffRegistry} from "../interfaces/IStaffRegistry.sol";

contract StaffRegistry is IStaffRegistry {
    ISchoolRoles public immutable ROLES;
    mapping(address => Staff) private _staff;

    error ZeroAddress();
    error EmptyName();
    error EmptyMetadataURI();
    error InvalidStaffId();
    error InvalidStaffType();
    error StaffAlreadyExists();
    error StaffNotFound();
    error StaffAlreadyRemoved();
    error InvalidStatusTransition();
    error Unauthorized();

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal view {
        if (!ROLES.isAdmin(msg.sender)) revert Unauthorized();
    }

    constructor(address rolesContract) {
        if (rolesContract == address(0)) revert ZeroAddress();
        ROLES = ISchoolRoles(rolesContract);
    }

    function createStaff(
        address staffAccount,
        uint256 staffId,
        StaffType staffType,
        string calldata fullName,
        string calldata metadataURI
    ) external onlyAdmin {
        if (staffAccount == address(0)) revert ZeroAddress();
        if (staffId == 0) revert InvalidStaffId();
        if (staffType == StaffType.NONE) revert InvalidStaffType();
        if (bytes(fullName).length == 0) revert EmptyName();
        if (bytes(metadataURI).length == 0) revert EmptyMetadataURI();
        if (_staff[staffAccount].status != StaffStatus.NONE) revert StaffAlreadyExists();

        _staff[staffAccount] = Staff({
            staffId: staffId,
            staffType: staffType,
            fullName: fullName,
            metadataURI: metadataURI,
            status: StaffStatus.ACTIVE,
            createdAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp)
        });

        emit StaffCreated(staffAccount, staffId, staffType, fullName, msg.sender);
    }

    function updateStaff(address staffAccount, StaffType staffType, string calldata fullName, string calldata metadataURI)
        external
        onlyAdmin
    {
        Staff storage staff = _staff[staffAccount];
        if (staff.status == StaffStatus.NONE) revert StaffNotFound();
        if (staff.status == StaffStatus.REMOVED) revert StaffAlreadyRemoved();
        if (staffType == StaffType.NONE) revert InvalidStaffType();
        if (bytes(fullName).length == 0) revert EmptyName();
        if (bytes(metadataURI).length == 0) revert EmptyMetadataURI();

        staff.staffType = staffType;
        staff.fullName = fullName;
        staff.metadataURI = metadataURI;
        staff.updatedAt = uint64(block.timestamp);

        emit StaffUpdated(staffAccount, staffType, fullName, metadataURI, msg.sender);
    }

    function suspendStaff(address staffAccount) external onlyAdmin {
        Staff storage staff = _staff[staffAccount];
        if (staff.status == StaffStatus.NONE) revert StaffNotFound();
        if (staff.status == StaffStatus.REMOVED) revert StaffAlreadyRemoved();
        if (staff.status != StaffStatus.ACTIVE) revert InvalidStatusTransition();

        staff.status = StaffStatus.SUSPENDED;
        staff.updatedAt = uint64(block.timestamp);

        emit StaffSuspended(staffAccount, msg.sender);
    }

    function unsuspendStaff(address staffAccount) external onlyAdmin {
        Staff storage staff = _staff[staffAccount];
        if (staff.status == StaffStatus.NONE) revert StaffNotFound();
        if (staff.status == StaffStatus.REMOVED) revert StaffAlreadyRemoved();
        if (staff.status != StaffStatus.SUSPENDED) revert InvalidStatusTransition();

        staff.status = StaffStatus.ACTIVE;
        staff.updatedAt = uint64(block.timestamp);

        emit StaffUnsuspended(staffAccount, msg.sender);
    }

    function removeStaff(address staffAccount) external onlyAdmin {
        Staff storage staff = _staff[staffAccount];
        if (staff.status == StaffStatus.NONE) revert StaffNotFound();
        if (staff.status == StaffStatus.REMOVED) revert InvalidStatusTransition();

        staff.status = StaffStatus.REMOVED;
        staff.updatedAt = uint64(block.timestamp);

        emit StaffRemoved(staffAccount, msg.sender);
    }

    function getStaff(address staffAccount) external view returns (Staff memory) {
        Staff memory staff = _staff[staffAccount];
        if (staff.status == StaffStatus.NONE) revert StaffNotFound();
        return staff;
    }

    function staffExists(address staffAccount) external view returns (bool) {
        return _staff[staffAccount].status != StaffStatus.NONE;
    }
}
