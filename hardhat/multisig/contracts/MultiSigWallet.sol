// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MultiSigWallet {
  error NotOwner();
  error InvalidOwners();
  error InvalidThreshold();
  error TxDoesNotExist();
  error TxAlreadyExecuted();
  error TxAlreadyApproved();
  error NotEnoughApprovals();
  error TxExecutionFailed();

  event Deposit(address indexed sender, uint256 amount, uint256 balance);
  event SubmitTransaction(
    address indexed owner,
    uint256 indexed txId,
    address indexed to,
    uint256 value,
    bytes data
  );
  event ApproveTransaction(address indexed owner, uint256 indexed txId);
  event ExecuteTransaction(address indexed executor, uint256 indexed txId);

  struct Transaction {
    address to;
    uint256 value;
    bytes data;
    bool executed;
    uint256 approvals;
  }

  address[] public owners;
  mapping(address => bool) public isOwner;
  uint256 public threshold;

  Transaction[] public transactions;
  mapping(uint256 => mapping(address => bool)) public approvedBy;

  modifier onlyOwner() {
    if (!isOwner[msg.sender]) revert NotOwner();
    _;
  }

  modifier txExists(uint256 txId) {
    if (txId >= transactions.length) revert TxDoesNotExist();
    _;
  }

  modifier notExecuted(uint256 txId) {
    if (transactions[txId].executed) revert TxAlreadyExecuted();
    _;
  }

  constructor(address[] memory _owners, uint256 _threshold) {
    if (_owners.length == 0) revert InvalidOwners();
    if (_threshold == 0 || _threshold > _owners.length) revert InvalidThreshold();

    for (uint256 i = 0; i < _owners.length; i++) {
      address owner = _owners[i];
      if (owner == address(0) || isOwner[owner]) revert InvalidOwners();

      isOwner[owner] = true;
      owners.push(owner);
    }

    threshold = _threshold;
  }

  receive() external payable {
    emit Deposit(msg.sender, msg.value, address(this).balance);
  }

  function submitTransaction(address to, uint256 value, bytes calldata data)
    external
    onlyOwner
    returns (uint256 txId)
  {
    txId = transactions.length;
    transactions.push(
      Transaction({to: to, value: value, data: data, executed: false, approvals: 0})
    );

    emit SubmitTransaction(msg.sender, txId, to, value, data);
  }

  function approveTransaction(uint256 txId)
    external
    onlyOwner
    txExists(txId)
    notExecuted(txId)
  {
    if (approvedBy[txId][msg.sender]) revert TxAlreadyApproved();

    approvedBy[txId][msg.sender] = true;
    transactions[txId].approvals += 1;

    emit ApproveTransaction(msg.sender, txId);
  }

  function executeTransaction(uint256 txId) external txExists(txId) notExecuted(txId) {
    Transaction storage txn = transactions[txId];

    if (txn.approvals < threshold) revert NotEnoughApprovals();

    txn.executed = true;

    (bool ok,) = txn.to.call{value: txn.value}(txn.data);
    if (!ok) revert TxExecutionFailed();

    emit ExecuteTransaction(msg.sender, txId);
  }

  function getOwners() external view returns (address[] memory) {
    return owners;
  }

  function getTransactionCount() external view returns (uint256) {
    return transactions.length;
  }
}
