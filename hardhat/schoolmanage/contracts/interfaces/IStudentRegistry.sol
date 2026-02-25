// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStudentRegistry {
    enum Level {
        NONE,
        L100,
        L200,
        L300,
        L400,
        L500
    }

    enum StudentStatus {
        NONE,
        ACTIVE,
        SUSPENDED,
        REMOVED
    }

    struct Student {
        uint256 studentId;
        string fullName;
        string metadataURI;
        Level level;
        StudentStatus status;
        uint64 createdAt;
        uint64 updatedAt;
    }

    event StudentCreated(
        address indexed studentAccount,
        uint256 indexed studentId,
        string fullName,
        Level level,
        address indexed createdBy
    );
    event StudentUpdated(address indexed studentAccount, string fullName, string metadataURI, address indexed updatedBy);
    event StudentLevelUpdated(address indexed studentAccount, Level previousLevel, Level newLevel, address indexed updatedBy);
    event StudentSuspended(address indexed studentAccount, address indexed suspendedBy);
    event StudentUnsuspended(address indexed studentAccount, address indexed unsuspendedBy);
    event StudentRemoved(address indexed studentAccount, address indexed removedBy);

    function createStudent(
        address studentAccount,
        uint256 studentId,
        string calldata fullName,
        string calldata metadataURI,
        Level level
    ) external;

    function updateStudent(address studentAccount, string calldata fullName, string calldata metadataURI) external;
    function updateStudentLevel(address studentAccount, Level level) external;
    function suspendStudent(address studentAccount) external;
    function unsuspendStudent(address studentAccount) external;
    function removeStudent(address studentAccount) external;

    function getStudent(address studentAccount) external view returns (Student memory);
    function studentExists(address studentAccount) external view returns (bool);
}
