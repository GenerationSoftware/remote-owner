// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RemoteOwner } from "../RemoteOwner.sol";

/* ============ Errors ============ */

/// @notice Thrown if the recovery address is set to the zero address.
error RecoveryAddressZero();

/// @notice Thrown if the caller is not the recovery address.
error CallerNotRecoveryAddress(address caller, address recoveryAddress);

/// @notice Throw if recovery has already been initiated.
/// @param recoveryInitiatedAt The timestamp at which recovery was initiated
error RecoveryClaimAlreadyInitiated(uint256 recoveryInitiatedAt);

/// @notice Thrown if a recovery action is made, but a recovery claim has not been made.
error RecoveryClaimNotInitiated();

/// @notice Thrown if a recovery claim is not active yet.
/// @param timestamp The timestamp at which the action was taken
/// @param claimActiveAt The timestamp at which the claim will be active
error RecoveryClaimNotActive(uint256 timestamp, uint256 claimActiveAt);

/// @title RemoteOwnerRecoverable
/// @author G9 Software Inc.
/// @notice Extension for the RemoteOwner contract that allows a recovery address to claim
/// ownership after a predefined delay period.
contract RemoteOwnerRecoverable is RemoteOwner {
  /* ============ Events ============ */

  /// @notice Emitted when recovery permission is transferred to a new address.
  /// @param recoveryAddress The new recovery address
  event TransferRecoveryPermission(address indexed recoveryAddress);

  /// @notice Emitted when a recovery claim has been initiated.
  /// @param recoveryAddress The recovery address that has initiated the claim
  /// @param initiatedAt The timestamp at which the claim was initiated
  event InitiateRecoveryClaim(address indexed recoveryAddress, uint256 initiatedAt);

  /// @notice Emitted when a recovery claim is renounced by the recovery address.
  /// @param recoveryAddress The active recovery address
  event RenounceRecoveryClaim(address indexed recoveryAddress);

  /* ============ Variables ============ */

  /// @notice The delay in seconds until a recovery claim is activated
  uint256 public immutable recoveryDelay;

  /// @notice Recovery address that can claim ownership after a predefined delay.
  address internal _recoveryAddress;

  /// @notice The timestamp at which the recovery process was initiated.
  /// @dev Set to zero when no recovery is active
  uint256 internal _recoveryInitiatedAt;

  /* ============ Constructor ============ */

  /**
   * @notice RemoteOwnerRecoverable constructor
   * @param originChainId_ The ID of the origin chain
   * @param executor_ The address of the permitted executor
   * @param __owner The remote owner address
   * @param recoveryAddress_ The address that can recover ownership
   * @param recoveryDelay_ The delay in seconds until a recovery claim is activated
   */
  constructor(
    uint256 originChainId_,
    address executor_,
    address __owner,
    address recoveryAddress_,
    uint256 recoveryDelay_
  ) RemoteOwner(originChainId_, executor_, __owner) {
    if (address(0) == recoveryAddress_) revert RecoveryAddressZero();
    _recoveryAddress = recoveryAddress_;
    recoveryDelay = recoveryDelay_;
  }

  /* ============ Modifiers ============ */

  modifier onlyRecoveryAddress() {
    if (msg.sender != _recoveryAddress)
      revert CallerNotRecoveryAddress(msg.sender, _recoveryAddress);
    _;
  }

  /**
   * @notice Asserts that the sender is the recovery address and a recovery claim has been made
   * and has passed the recovery delay period.
   */
  modifier onlyActiveRecoveryOwner() {
    if (msg.sender != _recoveryAddress)
      revert CallerNotRecoveryAddress(msg.sender, _recoveryAddress);
    if (_recoveryInitiatedAt == 0) revert RecoveryClaimNotInitiated();
    if (block.timestamp < _recoveryInitiatedAt + recoveryDelay)
      revert RecoveryClaimNotActive(block.timestamp, _recoveryInitiatedAt + recoveryDelay);
    _;
  }

  /* ============ Getters ============ */

  /**
   * @notice Gets the current recovery address.
   * @return The current recovery address
   */
  function recoveryAddress() external view returns (address) {
    return _recoveryAddress;
  }

  /**
   * @notice Gets the timestamp at which a recovery claim has been made.
   * @dev Returns zero if no recovery claim has been initiated.
   * @return The timestamp at which a recovery claim has been made
   */
  function recoveryInitiatedAt() external view returns (uint256) {
    return _recoveryInitiatedAt;
  }

  /* ============ External Functions ============ */

  /**
   * @notice Executes a call on the target contract. Can only be called by the recovery address
   * after a recovery claim has been made and the recovery delay has passed.
   * @param target The address to call
   * @param value Any eth value to pass along with the call
   * @param data The calldata
   * @return The return data of the call
   */
  function recoveryExecute(
    address target,
    uint256 value,
    bytes calldata data
  ) external onlyActiveRecoveryOwner returns (bytes memory) {
    return _execute(target, value, data);
  }

  /**
   * @notice Returns whether the current recovery claim is active or not.
   * @dev Returns false if there is no current recovery claim
   * @return True if the claim is active, false if not
   */
  function recoveryClaimActive() external view returns (bool) {
    if (_recoveryInitiatedAt == 0) return false;
    return block.timestamp >= _recoveryInitiatedAt + recoveryDelay;
  }

  /**
   * @notice Initiates a claim on recovery ownership.
   * @dev Only callable by the recovery address.
   */
  function initiateRecoveryClaim() external onlyRecoveryAddress {
    if (_recoveryInitiatedAt != 0) revert RecoveryClaimAlreadyInitiated(_recoveryInitiatedAt);
    _recoveryInitiatedAt = block.timestamp;
    emit InitiateRecoveryClaim(_recoveryAddress, block.timestamp);
  }

  /**
   * @notice Renounces recovery ownership.
   * @dev Only callable by the recovery address.
   * @dev The recovery address will still be able to initiate a new claim on recovery ownership
   * after this is called, but the delay will be restarted.
   */
  function renounceRecoveryClaim() external onlyRecoveryAddress {
    _recoveryInitiatedAt = 0;
    emit RenounceRecoveryClaim(_recoveryAddress);
  }

  /**
   * @notice Prevents any address from recovering ownership and revokes any active recovery claims.
   */
  function revokeRecoveryPermission() external virtual onlyExecutorAndOriginChain onlyOwner {
    _recoveryAddress = address(0);
    _recoveryInitiatedAt = 0;
    emit TransferRecoveryPermission(address(0));
  }

  /**
   * @notice Transfer recovery permission to a new address.
   * @dev Also denies any active recovery claims by resetting the initiated recovery timestamp.
   * @param _newRecoveryAddress The new address that is permitted to recover ownership
   */
  function transferRecoveryPermission(
    address _newRecoveryAddress
  ) external onlyExecutorAndOriginChain onlyOwner {
    if (address(0) == _newRecoveryAddress) revert RecoveryAddressZero();
    _recoveryAddress = _newRecoveryAddress;
    _recoveryInitiatedAt = 0;
    emit TransferRecoveryPermission(_newRecoveryAddress);
  }
}
