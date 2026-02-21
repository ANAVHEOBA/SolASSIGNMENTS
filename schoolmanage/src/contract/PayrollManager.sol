// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPayrollManager} from "../interfaces/IPayrollManager.sol";
import {ISchoolRoles} from "../interfaces/ISchoolRoles.sol";
import {IStaffRegistry} from "../interfaces/IStaffRegistry.sol";

interface IERC20Payroll {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}

contract PayrollManager is IPayrollManager {
    ISchoolRoles public immutable ROLES;
    IStaffRegistry public immutable STAFF_REGISTRY;

    mapping(address => StaffPayroll) private _staffPayroll;
    mapping(address => uint256) private _tokenPayrollBalance;

    error Unauthorized();
    error ZeroAddress();
    error InvalidAmount();
    error InvalidPayInterval();
    error StaffNotEligible();
    error PayrollNotConfigured();
    error NoClaimableSalary();
    error InsufficientPayrollBalance();
    error TokenTransferFailed();
    error DurationOverflow();

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal view {
        if (!ROLES.isAdmin(msg.sender)) revert Unauthorized();
    }

    constructor(address rolesContract, address staffRegistryContract) {
        if (rolesContract == address(0) || staffRegistryContract == address(0)) revert ZeroAddress();
        ROLES = ISchoolRoles(rolesContract);
        STAFF_REGISTRY = IStaffRegistry(staffRegistryContract);
    }

    function setStaffSalary(
        address staffAccount,
        address token,
        uint256 salaryPerPeriod,
        uint64 payInterval,
        bool active
    ) external onlyAdmin {
        if (staffAccount == address(0) || token == address(0)) revert ZeroAddress();
        if (salaryPerPeriod == 0) revert InvalidAmount();
        if (payInterval == 0) revert InvalidPayInterval();

        _requireActiveStaff(staffAccount);

        uint64 lastPaidAt = _staffPayroll[staffAccount].lastPaidAt;
        if (lastPaidAt == 0) {
            lastPaidAt = uint64(block.timestamp);
        }

        _staffPayroll[staffAccount] = StaffPayroll({
            token: token,
            salaryPerPeriod: salaryPerPeriod,
            payInterval: payInterval,
            lastPaidAt: lastPaidAt,
            active: active
        });

        emit SalaryConfigured(staffAccount, token, salaryPerPeriod, payInterval, active, msg.sender);
    }

    function fundPayroll(address token, uint256 amount) external onlyAdmin {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        _safeTransferFrom(token, msg.sender, address(this), amount);
        _tokenPayrollBalance[token] += amount;

        emit PayrollFunded(token, amount, msg.sender);
    }

    function payStaff(address staffAccount, uint256 amount) external onlyAdmin {
        if (amount == 0) revert InvalidAmount();

        StaffPayroll memory payroll = _staffPayroll[staffAccount];
        if (!payroll.active || payroll.token == address(0)) revert PayrollNotConfigured();
        _requireActiveStaff(staffAccount);

        _payout(staffAccount, payroll.token, amount);
        emit SalaryPaid(staffAccount, payroll.token, amount, msg.sender);
    }

    function claimSalary() external {
        if (!ROLES.isStaff(msg.sender)) revert Unauthorized();

        StaffPayroll storage payroll = _staffPayroll[msg.sender];
        if (!payroll.active || payroll.token == address(0)) revert PayrollNotConfigured();
        _requireActiveStaff(msg.sender);

        uint64 elapsed = uint64(block.timestamp) - payroll.lastPaidAt;
        uint256 periods = elapsed / payroll.payInterval;
        if (periods == 0) revert NoClaimableSalary();

        uint256 amount = periods * payroll.salaryPerPeriod;
        _payout(msg.sender, payroll.token, amount);

        uint256 paidDuration = periods * payroll.payInterval;
        uint256 updatedLastPaidAt = uint256(payroll.lastPaidAt) + paidDuration;
        if (updatedLastPaidAt > type(uint64).max) revert DurationOverflow();
        // forge-lint: disable-next-line(unsafe-typecast)
        payroll.lastPaidAt = uint64(updatedLastPaidAt);
        emit SalaryClaimed(msg.sender, payroll.token, amount);
    }

    function getStaffPayroll(address staffAccount) external view returns (StaffPayroll memory) {
        return _staffPayroll[staffAccount];
    }

    function claimableSalary(address staffAccount) external view returns (uint256) {
        StaffPayroll memory payroll = _staffPayroll[staffAccount];
        if (!payroll.active || payroll.token == address(0)) return 0;

        IStaffRegistry.Staff memory staff = STAFF_REGISTRY.getStaff(staffAccount);
        if (staff.status != IStaffRegistry.StaffStatus.ACTIVE) return 0;

        uint256 elapsed = block.timestamp - payroll.lastPaidAt;
        uint256 periods = elapsed / payroll.payInterval;
        return periods * payroll.salaryPerPeriod;
    }

    function _payout(address to, address token, uint256 amount) internal {
        uint256 available = _tokenPayrollBalance[token];
        if (available < amount) revert InsufficientPayrollBalance();

        _tokenPayrollBalance[token] = available - amount;
        _safeTransfer(token, to, amount);
    }

    function _requireActiveStaff(address staffAccount) internal view {
        IStaffRegistry.Staff memory staff = STAFF_REGISTRY.getStaff(staffAccount);
        if (staff.status != IStaffRegistry.StaffStatus.ACTIVE) revert StaffNotEligible();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Payroll.transferFrom.selector, from, to, amount)
        );

        if (!ok) revert TokenTransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TokenTransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Payroll.transfer.selector, to, amount)
        );

        if (!ok) revert TokenTransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TokenTransferFailed();
    }
}
