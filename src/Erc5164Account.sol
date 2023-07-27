// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ExecutorAware } from "erc5164/abstract/ExecutorAware.sol";

contract Erc5164Account is ExecutorAware {
  /* ============ Events ============ */

  /**
   * @notice Emitted when the OriginChainOwner has been set.
   * @param owner Address of the OriginChainOwner
   */
  event OriginChainOwnerSet(address owner);

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the originChainId passed to the constructor is zero.
  error OriginChainIdZero();

  /// @notice Thrown when the OriginChainOwner address passed to the constructor is zero address.
  error OriginChainOwnerZeroAddress();

  /// @notice Thrown when the executor address passed to the constructor is the zero address.
  error ExecutorZeroAddress();

  /// @notice Thrown when the message was dispatched from an unsupported chain ID.
  error OriginChainIdUnsupported(uint256 fromChainId);

  /// @notice Thrown when the message was not executed by the executor.
  error LocalSenderNotExecutor(address sender);

  /// @notice Thrown when the message was not dispatched by the OriginChainOwner on the origin chain.
  error OriginSenderNotOwner(address sender);

  /* ============ Variables ============ */

  /// @notice ID of the origin chain that dispatches the auction auction results and random number.
  uint256 internal immutable _originChainId;

  /// @notice Address of the OriginChainOwner on the origin chain that dispatches the auction auction results and random number.
  address internal _originChainOwner;

  /* ============ Constructor ============ */

  /**
   * @notice ownerReceiver constructor.
   */
  constructor(
    uint256 originChainId_,
    address executor_,
    address __originChainOwner
  ) ExecutorAware(executor_) {
    if (originChainId_ == 0) revert OriginChainIdZero();
    if (address(executor_) == address(0)) revert ExecutorZeroAddress();
    _originChainId = originChainId_;
    _setOriginChainOwner(__originChainOwner);
  }

  /* ============ External Functions ============ */

  function execute(address target, uint256 value, bytes calldata data) external {
    _checkSender();
    (bool success, bytes memory returnData) = target.call{ value: value }(data);
    if (!success) revert(string(returnData));
  }

  /**
   * @notice Get the ID of the origin chain.
   * @return ID of the origin chain
   */
  function originChainId() external view returns (uint256) {
    return _originChainId;
  }

  /**
   * @notice Get the address of the OriginChainOwner on the origin chain.
   * @return Address of the OriginChainOwner on the origin chain
   */
  function owner() external view returns (address) {
    return _originChainOwner;
  }

  /* ============ Setters ============ */

  /**
   * @notice Set the OriginChainOwner address.
   * @dev Can only be called once.
   *      If the transaction get front-run at deployment, we can always re-deploy the contract.
   */
  function setOriginChainOwner(address _newOriginChainOwner) external {
    _checkSender();
    _setOriginChainOwner(_newOriginChainOwner);
  }

  /* ============ Internal Functions ============ */

  function _setOriginChainOwner(address _newOriginChainOwner) internal {
    if (_newOriginChainOwner == address(0)) revert OriginChainOwnerZeroAddress();

    _originChainOwner = _newOriginChainOwner;

    emit OriginChainOwnerSet(_newOriginChainOwner);
  }

  /**
   * @notice Checks that:
   *          - the call has been dispatched from the supported chain
   *          - the sender on the receiving chain is the executor
   *          - the sender on the origin chain is the DrawMangerAdapter
   */
  function _checkSender() internal view {
    if (_fromChainId() != _originChainId) revert OriginChainIdUnsupported(_fromChainId());
    if (!isTrustedExecutor(msg.sender)) revert LocalSenderNotExecutor(msg.sender);
    if (_msgSender() != address(_originChainOwner)) revert OriginSenderNotOwner(_msgSender());
  }
}
