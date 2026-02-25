// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStudentRegistry} from "./IStudentRegistry.sol";

interface IFeeManager {
    struct FeeConfig {
        uint256 feeId;
        string title;
        address token;
        uint256 amount;
        bool active;
    }

    struct StudentFee {
        uint256 feeId;
        uint256 amountDue;
        uint256 amountPaid;
        bool settled;
    }

    event LevelFeeConfigured(
        IStudentRegistry.Level indexed level,
        uint256 indexed feeId,
        string title,
        address token,
        uint256 amount,
        bool active,
        address indexed configuredBy
    );
    event FeeConfigured(
        uint256 indexed feeId,
        string title,
        address indexed token,
        uint256 amount,
        bool active,
        address indexed configuredBy
    );
    event FeeAssigned(
        address indexed studentAccount,
        uint256 indexed feeId,
        uint256 amountDue,
        address assignedBy
    );
    event FeePaid(
        address indexed studentAccount,
        uint256 indexed feeId,
        address indexed token,
        uint256 amount,
        address payer
    );
    event FeeStatusUpdated(address indexed studentAccount, uint256 indexed feeId, bool settled);

    function setFee(
        uint256 feeId,
        string calldata title,
        address token,
        uint256 amount,
        bool active
    ) external;
    function setLevelFee(
        IStudentRegistry.Level level,
        uint256 feeId,
        string calldata title,
        address token,
        uint256 amount,
        bool active
    ) external;

    function assignFeeToStudent(address studentAccount, uint256 feeId, uint256 amountDue) external;
    function assignFeeByLevel(address studentAccount, uint256 feeId) external;
    function payFee(address studentAccount, uint256 feeId, uint256 amount) external;
    function markFeeSettled(address studentAccount, uint256 feeId, bool settled) external;

    function getFee(uint256 feeId) external view returns (FeeConfig memory);
    function getLevelFee(IStudentRegistry.Level level, uint256 feeId) external view returns (FeeConfig memory);
    function getStudentFee(address studentAccount, uint256 feeId) external view returns (StudentFee memory);
}
