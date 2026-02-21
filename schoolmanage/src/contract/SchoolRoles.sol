// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISchoolRoles} from "../interfaces/ISchoolRoles.sol";

contract SchoolRoles is ISchoolRoles {
    mapping(address => Role) private _roles;
    uint256 private _adminCount;

    error ZeroAddress();
    error NotAdmin();
    error InvalidRole();
    error RoleAlreadyAssigned();
    error RoleNotAssigned();
    error CannotRemoveLastAdmin();

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal view {
        if (!isAdmin(msg.sender)) revert NotAdmin();
    }

    constructor(address initialAdmin) {
        if (initialAdmin == address(0)) revert ZeroAddress();

        _roles[initialAdmin] = Role.ADMIN;
        _adminCount = 1;
        emit RoleGranted(initialAdmin, Role.ADMIN, initialAdmin);
    }

    function grantRole(address account, Role role) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        if (role == Role.NONE) revert InvalidRole();
        if (_roles[account] == role) revert RoleAlreadyAssigned();

        Role currentRole = _roles[account];
        if (currentRole == Role.ADMIN) {
            unchecked {
                _adminCount -= 1;
            }
        }

        _roles[account] = role;
        if (role == Role.ADMIN) {
            _adminCount += 1;
        }

        emit RoleGranted(account, role, msg.sender);
    }

    function revokeRole(address account) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();

        Role currentRole = _roles[account];
        if (currentRole == Role.NONE) revert RoleNotAssigned();

        if (currentRole == Role.ADMIN && _adminCount == 1) {
            revert CannotRemoveLastAdmin();
        }

        if (currentRole == Role.ADMIN) {
            unchecked {
                _adminCount -= 1;
            }
        }
        _roles[account] = Role.NONE;

        emit RoleRevoked(account, currentRole, msg.sender);
    }

    function getRole(address account) external view returns (Role) {
        return _roles[account];
    }

    function isAdmin(address account) public view returns (bool) {
        return _roles[account] == Role.ADMIN;
    }

    function isStaff(address account) public view returns (bool) {
        return _roles[account] == Role.STAFF;
    }

    function isStudent(address account) public view returns (bool) {
        return _roles[account] == Role.STUDENT;
    }
}
