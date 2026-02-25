// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISchoolRoles} from "../interfaces/ISchoolRoles.sol";
import {IStudentRegistry} from "../interfaces/IStudentRegistry.sol";

contract StudentRegistry is IStudentRegistry {
    ISchoolRoles public immutable ROLES;
    mapping(address => Student) private _students;

    error ZeroAddress();
    error EmptyName();
    error EmptyMetadataURI();
    error InvalidStudentId();
    error InvalidLevel();
    error StudentAlreadyExists();
    error StudentNotFound();
    error StudentAlreadyRemoved();
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

    function createStudent(
        address studentAccount,
        uint256 studentId,
        string calldata fullName,
        string calldata metadataURI,
        Level level
    ) external onlyAdmin {
        if (studentAccount == address(0)) revert ZeroAddress();
        if (studentId == 0) revert InvalidStudentId();
        if (level == Level.NONE) revert InvalidLevel();
        if (bytes(fullName).length == 0) revert EmptyName();
        if (bytes(metadataURI).length == 0) revert EmptyMetadataURI();
        if (_students[studentAccount].status != StudentStatus.NONE) revert StudentAlreadyExists();

        _students[studentAccount] = Student({
            studentId: studentId,
            fullName: fullName,
            metadataURI: metadataURI,
            level: level,
            status: StudentStatus.ACTIVE,
            createdAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp)
        });

        emit StudentCreated(studentAccount, studentId, fullName, level, msg.sender);
    }

    function updateStudent(address studentAccount, string calldata fullName, string calldata metadataURI)
        external
        onlyAdmin
    {
        Student storage student = _students[studentAccount];
        if (student.status == StudentStatus.NONE) revert StudentNotFound();
        if (student.status == StudentStatus.REMOVED) revert StudentAlreadyRemoved();
        if (bytes(fullName).length == 0) revert EmptyName();
        if (bytes(metadataURI).length == 0) revert EmptyMetadataURI();

        student.fullName = fullName;
        student.metadataURI = metadataURI;
        student.updatedAt = uint64(block.timestamp);

        emit StudentUpdated(studentAccount, fullName, metadataURI, msg.sender);
    }

    function updateStudentLevel(address studentAccount, Level level) external onlyAdmin {
        Student storage student = _students[studentAccount];
        if (student.status == StudentStatus.NONE) revert StudentNotFound();
        if (student.status == StudentStatus.REMOVED) revert StudentAlreadyRemoved();
        if (level == Level.NONE) revert InvalidLevel();

        Level previousLevel = student.level;
        student.level = level;
        student.updatedAt = uint64(block.timestamp);

        emit StudentLevelUpdated(studentAccount, previousLevel, level, msg.sender);
    }

    function suspendStudent(address studentAccount) external onlyAdmin {
        Student storage student = _students[studentAccount];
        if (student.status == StudentStatus.NONE) revert StudentNotFound();
        if (student.status == StudentStatus.REMOVED) revert StudentAlreadyRemoved();
        if (student.status != StudentStatus.ACTIVE) revert InvalidStatusTransition();

        student.status = StudentStatus.SUSPENDED;
        student.updatedAt = uint64(block.timestamp);

        emit StudentSuspended(studentAccount, msg.sender);
    }

    function unsuspendStudent(address studentAccount) external onlyAdmin {
        Student storage student = _students[studentAccount];
        if (student.status == StudentStatus.NONE) revert StudentNotFound();
        if (student.status == StudentStatus.REMOVED) revert StudentAlreadyRemoved();
        if (student.status != StudentStatus.SUSPENDED) revert InvalidStatusTransition();

        student.status = StudentStatus.ACTIVE;
        student.updatedAt = uint64(block.timestamp);

        emit StudentUnsuspended(studentAccount, msg.sender);
    }

    function removeStudent(address studentAccount) external onlyAdmin {
        Student storage student = _students[studentAccount];
        if (student.status == StudentStatus.NONE) revert StudentNotFound();
        if (student.status == StudentStatus.REMOVED) revert InvalidStatusTransition();

        student.status = StudentStatus.REMOVED;
        student.updatedAt = uint64(block.timestamp);

        emit StudentRemoved(studentAccount, msg.sender);
    }

    function getStudent(address studentAccount) external view returns (Student memory) {
        Student memory student = _students[studentAccount];
        if (student.status == StudentStatus.NONE) revert StudentNotFound();
        return student;
    }

    function studentExists(address studentAccount) external view returns (bool) {
        return _students[studentAccount].status != StudentStatus.NONE;
    }
}
