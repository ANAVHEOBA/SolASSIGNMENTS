// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPayrollManager {
    struct StaffPayroll {
        address token;
        uint256 salaryPerPeriod;
        uint64 payInterval;
        uint64 lastPaidAt;
        bool active;
    }

    event SalaryConfigured(
        address indexed staffAccount,
        address indexed token,
        uint256 salaryPerPeriod,
        uint64 payInterval,
        bool active,
        address indexed configuredBy
    );
    event PayrollFunded(address indexed token, uint256 amount, address indexed fundedBy);
    event SalaryPaid(
        address indexed staffAccount,
        address indexed token,
        uint256 amount,
        address paidBy
    );
    event SalaryClaimed(
        address indexed staffAccount,
        address indexed token,
        uint256 amount
    );

    function setStaffSalary(
        address staffAccount,
        address token,
        uint256 salaryPerPeriod,
        uint64 payInterval,
        bool active
    ) external;

    function fundPayroll(address token, uint256 amount) external;
    function payStaff(address staffAccount, uint256 amount) external;
    function claimSalary() external;

    function getStaffPayroll(address staffAccount) external view returns (StaffPayroll memory);
    function claimableSalary(address staffAccount) external view returns (uint256);
}
