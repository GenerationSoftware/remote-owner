// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ExecutorAware } from "erc5164-interfaces/abstract/ExecutorAware.sol";

/* ============ Custom Errors ============ */

/// @notice Thrown when the originChainId passed to the constructor is zero.
error OriginChainIdZero();

/// @notice Thrown when the Owner address passed to the constructor is zero address.
error OwnerZeroAddress();

/// @notice Thrown when the message was dispatched from an unsupported chain ID.
error OriginChainIdUnsupported(uint256 fromChainId);

/// @notice Thrown when the message was not executed by the executor.
error LocalSenderNotExecutor(address sender);

/// @notice Thrown when the message was not dispatched by the Owner on the origin chain.
error OriginSenderNotOwner(address sender);

/// @notice Thrown when the message was not dispatched by the pending owner on the origin chain.
error OriginSenderNotPendingOwner(address sender);

/// @notice Thrown when the call to the target contract failed.
error CallFailed(bytes returnData);

/// @title RemoteOwner
/// @author G9 Software Inc.
/// @notice RemoteOwner allows a contract on one chain to control a contract on another chain.
contract RemoteOwner is ExecutorAware {

  /* ============ Events ============ */

  /**
    * @dev Emitted when `_pendingOwner` has been changed.
    * @param pendingOwner new `_pendingOwner` address.
    */
  event OwnershipOffered(address indexed pendingOwner);

  /**
    * @dev Emitted when `_owner` has been changed.
    * @param previousOwner previous `_owner` address.
    * @param newOwner new `_owner` address.
    */
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @notice Emitted when ether is received to this contract via the `receive` function.
   * @param from The sender of the ether
   * @param value The value received
   */
  event Received(address from, uint256 value);

  /* ============ Variables ============ */

  /// @notice ID of the origin chain that dispatches the auction auction results and random number.
  uint256 internal immutable _originChainId;

  /// @notice Address of the Owner on the origin chain that dispatches the auction auction results and random number.
  address private _owner;
  address private _pendingOwner;

  /* ============ Constructor ============ */

  /**
   * @notice ownerReceiver constructor.
   */
  constructor(
    uint256 originChainId_,
    address executor_,
    address __owner
  ) ExecutorAware(executor_) {
    if (__owner == address(0)) revert OwnerZeroAddress();
    if (originChainId_ == 0) revert OriginChainIdZero();
    _originChainId = originChainId_;
    _setOwner(__owner);
  }

  /* ============ Receive Ether Function ============ */

  /// @dev Emits a `Received` event
  receive() external payable {
    emit Received(msg.sender, msg.value);
  }

  /* ============ External Functions ============ */

  function execute(address target, uint256 value, bytes calldata data) external onlyExecutorAndOriginChain onlyOwner returns (bytes memory) {
    (bool success, bytes memory returnData) = target.call{ value: value }(data);
    if (!success) revert CallFailed(returnData);
    assembly {
      return (add(returnData, 0x20), mload(returnData))
    }
  }

  /**
    * @notice Renounce ownership of the contract.
    * @dev Leaves the contract without owner. It will not be possible to call
    * `onlyOwner` functions anymore. Can only be called by the current owner.
    *
    * NOTE: Renouncing ownership will leave the contract without an owner,
    * thereby removing any functionality that is only available to the owner.
    */
  function renounceOwnership() external virtual onlyExecutorAndOriginChain onlyOwner {
      _setOwner(address(0));
  }

  /**
   * @notice Set the Owner address.
   * @dev Can only be called once.
   *      If the transaction get front-run at deployment, we can always re-deploy the contract.
   */
  function transferOwnership(address _newOwner) external onlyExecutorAndOriginChain onlyOwner {
    if (_newOwner == address(0)) revert OwnerZeroAddress();
    _pendingOwner = _newOwner;
    emit OwnershipOffered(_newOwner);
  }

  /**
  * @notice Allows the `_pendingOwner` address to finalize the transfer.
  * @dev This function is only callable by the `_pendingOwner`.
  */
  function claimOwnership() external onlyExecutorAndOriginChain onlyPendingOwner {
      _setOwner(_pendingOwner);
      _pendingOwner = address(0);
  }

  /* ============ Getters ============ */

  /**
   * @notice Get the ID of the origin chain.
   * @return ID of the origin chain
   */
  function originChainId() external view returns (uint256) {
    return _originChainId;
  }

  function owner() external view returns (address) {
    return _owner;
  }

  /**
    * @notice Gets current `_pendingOwner`.
    * @return Current `_pendingOwner` address.
    */
  function pendingOwner() external view virtual returns (address) {
      return _pendingOwner;
  }

  /* ============ Internal Functions ============ */

  function _setOwner(address _newOwner) internal {
    address _oldOwner = _owner;
    _owner = _newOwner;

    emit OwnershipTransferred(_oldOwner, _newOwner);
  }

  modifier onlyExecutorAndOriginChain() {
    if (!isTrustedExecutor(msg.sender)) revert LocalSenderNotExecutor(msg.sender);
    if (_fromChainId() != _originChainId) revert OriginChainIdUnsupported(_fromChainId());
    _;
  }

  /**
   * @notice Checks that:
   *          - the call has been dispatched from the supported chain
   *          - the sender on the receiving chain is the executor
   *          - the sender on the origin chain is the owner
   */
  modifier onlyOwner() {
    if (_msgSender() != address(_owner)) revert OriginSenderNotOwner(_msgSender());
    _;
  }

  /**
   * @notice Checks that:
   *          - the call has been dispatched from the supported chain
   *          - the sender on the receiving chain is the executor
   *          - the sender on the origin chain is the pending owner
   */
  modifier onlyPendingOwner() {
    if (_msgSender() != address(_pendingOwner)) revert OriginSenderNotPendingOwner(_msgSender());
    _;
  }
}
