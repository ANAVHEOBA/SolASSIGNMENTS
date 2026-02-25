// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IFeeManager} from "../interfaces/IFeeManager.sol";
import {ISchoolRoles} from "../interfaces/ISchoolRoles.sol";
import {IStudentRegistry} from "../interfaces/IStudentRegistry.sol";

interface IERC20Minimal {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract FeeManager is IFeeManager {
    ISchoolRoles public immutable ROLES;
    IStudentRegistry public immutable STUDENT_REGISTRY;

    mapping(uint256 => FeeConfig) private _fees;
    mapping(IStudentRegistry.Level => mapping(uint256 => FeeConfig)) private _levelFees;
    mapping(address => mapping(uint256 => StudentFee)) private _studentFees;
    mapping(address => mapping(uint256 => address)) private _studentFeeToken;
    mapping(address => mapping(uint256 => bool)) private _isAssigned;

    error Unauthorized();
    error ZeroAddress();
    error InvalidFeeId();
    error InvalidLevel();
    error EmptyTitle();
    error InvalidAmount();
    error FeeNotConfigured();
    error FeeInactive();
    error StudentNotEligible();
    error FeeNotAssigned();
    error FeeAlreadySettled();
    error PaymentTransferFailed();

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal view {
        if (!ROLES.isAdmin(msg.sender)) revert Unauthorized();
    }

    constructor(address rolesContract, address studentRegistryContract) {
        if (rolesContract == address(0) || studentRegistryContract == address(0)) revert ZeroAddress();
        ROLES = ISchoolRoles(rolesContract);
        STUDENT_REGISTRY = IStudentRegistry(studentRegistryContract);
    }

    function setFee(uint256 feeId, string calldata title, address token, uint256 amount, bool active) external onlyAdmin {
        _validateFeeInput(feeId, title, token, amount);

        _fees[feeId] = FeeConfig({feeId: feeId, title: title, token: token, amount: amount, active: active});
        emit FeeConfigured(feeId, title, token, amount, active, msg.sender);
    }

    function setLevelFee(
        IStudentRegistry.Level level,
        uint256 feeId,
        string calldata title,
        address token,
        uint256 amount,
        bool active
    ) external onlyAdmin {
        if (level == IStudentRegistry.Level.NONE) revert InvalidLevel();
        _validateFeeInput(feeId, title, token, amount);

        _levelFees[level][feeId] = FeeConfig({feeId: feeId, title: title, token: token, amount: amount, active: active});
        emit LevelFeeConfigured(level, feeId, title, token, amount, active, msg.sender);
    }

    function assignFeeToStudent(address studentAccount, uint256 feeId, uint256 amountDue) external onlyAdmin {
        if (amountDue == 0) revert InvalidAmount();
        _requireAssignableStudent(studentAccount);

        FeeConfig memory fee = _fees[feeId];
        if (fee.feeId == 0) revert FeeNotConfigured();
        if (!fee.active) revert FeeInactive();

        _assignStudentFee(studentAccount, feeId, fee.token, amountDue);
    }

    function assignFeeByLevel(address studentAccount, uint256 feeId) external onlyAdmin {
        IStudentRegistry.Student memory student = _requireAssignableStudent(studentAccount);
        if (student.level == IStudentRegistry.Level.NONE) revert InvalidLevel();

        FeeConfig memory fee = _levelFees[student.level][feeId];
        if (fee.feeId == 0) revert FeeNotConfigured();
        if (!fee.active) revert FeeInactive();

        _assignStudentFee(studentAccount, feeId, fee.token, fee.amount);
    }

    function payFee(address studentAccount, uint256 feeId, uint256 amount) external onlyAdmin {
        if (amount == 0) revert InvalidAmount();
        if (!_isAssigned[studentAccount][feeId]) revert FeeNotAssigned();
        _requireAssignableStudent(studentAccount);

        StudentFee storage studentFee = _studentFees[studentAccount][feeId];
        if (studentFee.settled) revert FeeAlreadySettled();

        address token = _studentFeeToken[studentAccount][feeId];
        if (token == address(0)) revert FeeNotConfigured();

        _safeTransferFrom(token, msg.sender, address(this), amount);

        studentFee.amountPaid += amount;
        bool isSettledNow = studentFee.amountPaid >= studentFee.amountDue;
        if (isSettledNow != studentFee.settled) {
            studentFee.settled = isSettledNow;
            emit FeeStatusUpdated(studentAccount, feeId, isSettledNow);
        }

        emit FeePaid(studentAccount, feeId, token, amount, msg.sender);
    }

    function markFeeSettled(address studentAccount, uint256 feeId, bool settled) external onlyAdmin {
        if (!_isAssigned[studentAccount][feeId]) revert FeeNotAssigned();

        StudentFee storage studentFee = _studentFees[studentAccount][feeId];
        studentFee.settled = settled;
        emit FeeStatusUpdated(studentAccount, feeId, settled);
    }

    function getFee(uint256 feeId) external view returns (FeeConfig memory) {
        return _fees[feeId];
    }

    function getLevelFee(IStudentRegistry.Level level, uint256 feeId) external view returns (FeeConfig memory) {
        return _levelFees[level][feeId];
    }

    function getStudentFee(address studentAccount, uint256 feeId) external view returns (StudentFee memory) {
        return _studentFees[studentAccount][feeId];
    }

    function _assignStudentFee(address studentAccount, uint256 feeId, address token, uint256 amountDue) internal {
        StudentFee storage studentFee = _studentFees[studentAccount][feeId];
        studentFee.feeId = feeId;
        studentFee.amountDue = amountDue;
        studentFee.settled = studentFee.amountPaid >= amountDue;

        _studentFeeToken[studentAccount][feeId] = token;
        _isAssigned[studentAccount][feeId] = true;

        emit FeeAssigned(studentAccount, feeId, amountDue, msg.sender);
        emit FeeStatusUpdated(studentAccount, feeId, studentFee.settled);
    }

    function _requireAssignableStudent(address studentAccount) internal view returns (IStudentRegistry.Student memory student) {
        if (studentAccount == address(0)) revert ZeroAddress();
        student = STUDENT_REGISTRY.getStudent(studentAccount);
        if (student.status == IStudentRegistry.StudentStatus.NONE) revert StudentNotEligible();
        if (student.status == IStudentRegistry.StudentStatus.REMOVED) revert StudentNotEligible();
    }

    function _validateFeeInput(uint256 feeId, string calldata title, address token, uint256 amount) internal pure {
        if (feeId == 0) revert InvalidFeeId();
        if (bytes(title).length == 0) revert EmptyTitle();
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, from, to, amount)
        );

        if (!ok) revert PaymentTransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert PaymentTransferFailed();
    }
}
