// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISchoolRoles {
    enum Role {
        NONE,
        STUDENT,
        STAFF,
        ADMIN
    }

    event RoleGranted(address indexed account, Role role, address indexed grantedBy);
    event RoleRevoked(address indexed account, Role role, address indexed revokedBy);

    function grantRole(address account, Role role) external;
    function revokeRole(address account) external;

    function getRole(address account) external view returns (Role);

    function isAdmin(address account) external view returns (bool);
    function isStaff(address account) external view returns (bool);
    function isStudent(address account) external view returns (bool);
}