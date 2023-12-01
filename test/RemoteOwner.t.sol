// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { RemoteOwner, OriginChainIdZero, LocalSenderNotExecutor, OriginChainIdUnsupported, OriginSenderNotOwner, OwnerZeroAddress, CallFailed, LocalSenderNotPendingExecutor } from "../src/RemoteOwner.sol";

import { ExecutorZeroAddress } from "erc5164-interfaces/abstract/ExecutorAware.sol";

import { RemoteOwnerCallEncoder } from "../src/libraries/RemoteOwnerCallEncoder.sol";

/// @dev See the "Writing Tests" section in the Foundry Book if this is your first time with Forge.
/// https://book.getfoundry.sh/forge/writing-tests
contract RemoteOwnerTest is Test {
  event Received(address indexed from, uint256 value);
  event OwnershipOffered(address indexed pendingOwner);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event PendingExecutorPermissionTransfer(address indexed pendingTrustedExecutor);
  event SetTrustedExecutor(address indexed previousExecutor, address indexed newExecutor);

  RemoteOwner account;

  address originChainOwner;

  address imposter;
  address executor2;

  address recipient;

  bytes recipientCalldata;
  bytes executeData;

  function setUp() public {
    originChainOwner = makeAddr("originChainOwner");
    imposter = makeAddr("imposter");
    executor2 = makeAddr("executor2");

    account = new RemoteOwner(1, address(this), originChainOwner);

    recipient = makeAddr("recipient");
    vm.etch(recipient, "recipient");
    recipientCalldata = abi.encodeWithSignature("getValue(uint256)", 42);
    vm.mockCall(recipient, recipientCalldata, abi.encode(1000));

    executeData = abi.encodePacked(
      RemoteOwnerCallEncoder.encodeCalldata(recipient, 0, recipientCalldata),
      bytes32(uint256(0x1234)),
      uint256(1),
      originChainOwner
    );
  }

  function testConstructor() public {
    assertEq(account.originChainId(), 1);
    assertEq(account.owner(), originChainOwner);
  }

  function testConstructor_OriginChainIdZero() public {
    vm.expectRevert(abi.encodeWithSelector(OriginChainIdZero.selector));
    new RemoteOwner(0, address(this), originChainOwner);
  }

  function testConstructor_ExecutorZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(ExecutorZeroAddress.selector));
    new RemoteOwner(1, address(0), originChainOwner);
  }

  function testConstructor_OwnerZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(OwnerZeroAddress.selector));
    new RemoteOwner(1, address(this), address(0));
  }

  function testReceiveEther() public {
    vm.expectEmit();
    emit Received(address(this), 1000);
    (bool sent, ) = address(account).call{ value: 1000 }(""); // send ether
    assertEq(sent, true);
  }

  function testExecute() public {
    (bool success, bytes memory result) = address(account).call(executeData);
    assertTrue(success, "was true");
    assertEq(abi.decode(result, (uint256)), 1000);
  }

  function testExecute_underlyingRevert() public {
    vm.mockCallRevert(recipient, recipientCalldata, abi.encodePacked("this reverts"));
    (bool success, bytes memory result) = address(account).call(executeData);
    assertFalse(success, "reverted");
    assertEq(result, abi.encodeWithSelector(CallFailed.selector, abi.encodePacked("this reverts")));
  }

  function testExecute_wrongExecutor() public {
    vm.startPrank(imposter);
    vm.expectRevert(abi.encodeWithSelector(LocalSenderNotExecutor.selector, imposter));
    address(account).call(executeData);
  }

  function testExecute_wrongChainId() public {
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.execute.selector, recipient, 0, recipientCalldata),
      bytes32(uint256(0x1234)),
      uint256(2),
      originChainOwner
    );
    vm.expectRevert(abi.encodeWithSelector(OriginChainIdUnsupported.selector, 2));
    address(account).call(executeData);
  }

  function testExecute_OriginSenderNotOwner() public {
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.execute.selector, recipient, 0, recipientCalldata),
      bytes32(uint256(0x1234)),
      uint256(1),
      imposter
    );
    vm.expectRevert(abi.encodeWithSelector(OriginSenderNotOwner.selector, imposter));
    address(account).call(executeData);
  }

  function testTransferOwnership_success() public {
    vm.expectEmit(true, true, true, true);
    emit OwnershipOffered(imposter);
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.transferOwnership.selector, imposter),
      bytes32(uint256(0x1234)),
      uint256(1),
      originChainOwner
    );
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertTrue(success, "was successful");
    assertEq(account.pendingOwner(), imposter);
  }

  function testTransferOwnership_LocalSenderNotExecutor() public {
    vm.startPrank(imposter);
    vm.expectRevert(abi.encodeWithSelector(LocalSenderNotExecutor.selector, imposter));
    account.transferOwnership(imposter);
  }

  function testTransferOwnership_invalidSender() public {
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.transferOwnership.selector, imposter),
      bytes32(uint256(0x1234)),
      uint256(1),
      imposter
    );
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertFalse(success, "failed");
    assertEq(returnData, abi.encodeWithSelector(OriginSenderNotOwner.selector, imposter));
  }

  function testTransferOwnership_newOwnerZeroAddress() public {
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.transferOwnership.selector, address(0)),
      bytes32(uint256(0x1234)),
      uint256(1),
      originChainOwner
    );
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertFalse(success, "failed");
    assertEq(returnData, abi.encodeWithSelector(OwnerZeroAddress.selector));
  }

  function testClaimOwnership() public {
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.transferOwnership.selector, imposter),
      bytes32(uint256(0x1234)),
      uint256(1),
      originChainOwner
    );
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertTrue(success, "transfer success");

    vm.expectEmit(true, true, true, true);
    emit OwnershipTransferred(originChainOwner, imposter);
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.claimOwnership.selector),
      bytes32(uint256(0x1234)),
      uint256(1),
      imposter
    );
    (success, returnData) = address(account).call(executeData);
    assertTrue(success, "claim success");

    assertEq(account.owner(), imposter);
    assertEq(account.pendingOwner(), address(0));
  }

  function testClaimOwnership_LocalSenderNotExecutor() public {
    vm.startPrank(imposter);
    vm.expectRevert(abi.encodeWithSelector(LocalSenderNotExecutor.selector, imposter));
    account.claimOwnership();
  }

  function testRenounceOwnership() public {
    vm.expectEmit(true, true, true, true);
    emit OwnershipTransferred(originChainOwner, address(0));
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.renounceOwnership.selector),
      bytes32(uint256(0x1234)),
      uint256(1),
      originChainOwner
    );
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertTrue(success, "transfer success");
  }

  function testRenounceOwnership_LocalSenderNotExecutor() public {
    vm.startPrank(imposter);
    vm.expectRevert(abi.encodeWithSelector(LocalSenderNotExecutor.selector, imposter));
    account.renounceOwnership();
  }

  function testTransferExecutorPermission_success() public {
    vm.expectEmit();
    emit PendingExecutorPermissionTransfer(executor2);
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.transferExecutorPermission.selector, executor2),
      bytes32(uint256(0x1234)),
      uint256(1),
      originChainOwner
    );
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertTrue(success, "was successful");
    assertEq(account.trustedExecutor(), address(this));
    assertEq(account.pendingTrustedExecutor(), executor2);
  }

  function testTransferExecutorPermission_LocalSenderNotExecutor() public {
    vm.startPrank(imposter);
    vm.expectRevert(abi.encodeWithSelector(LocalSenderNotExecutor.selector, imposter));
    account.transferExecutorPermission(executor2);
  }

  function testTransferExecutorPermission_invalidSender() public {
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.transferExecutorPermission.selector, executor2),
      bytes32(uint256(0x1234)),
      uint256(1),
      imposter
    );
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertFalse(success, "failed");
    assertEq(returnData, abi.encodeWithSelector(OriginSenderNotOwner.selector, imposter));
  }

  function testTransferExecutorPermission_newExecutorZeroAddress() public {
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.transferExecutorPermission.selector, address(0)),
      bytes32(uint256(0x1234)),
      uint256(1),
      originChainOwner
    );
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertFalse(success, "failed");
    assertEq(returnData, abi.encodeWithSelector(ExecutorZeroAddress.selector));
  }

  function testClaimExecutorPermission() public {
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.transferExecutorPermission.selector, executor2),
      bytes32(uint256(0x1234)),
      uint256(1),
      originChainOwner
    );
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertTrue(success, "declaration success");
    assertEq(account.trustedExecutor(), address(this));
    assertEq(account.pendingTrustedExecutor(), address(executor2));

    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.claimExecutorPermission.selector),
      bytes32(uint256(0x1234)),
      uint256(1),
      originChainOwner
    );
    vm.expectEmit();
    emit SetTrustedExecutor(address(this), executor2);
    vm.startPrank(executor2);
    (success, returnData) = address(account).call(executeData);
    vm.stopPrank();
    assertTrue(success, "activation success");

    assertEq(account.trustedExecutor(), executor2);
    assertEq(account.pendingTrustedExecutor(), address(0));
  }

  function testClaimExecutorPermission_LocalSenderNotPendingExecutor() public {
    vm.expectRevert(abi.encodeWithSelector(LocalSenderNotPendingExecutor.selector, address(this)));
    account.claimExecutorPermission();
  }

  function testClaimExecutorPermission_OriginSenderNotOwner() public {
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.transferExecutorPermission.selector, executor2),
      bytes32(uint256(0x1234)),
      uint256(1),
      originChainOwner
    );
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertTrue(success, "declaration success");

    vm.startPrank(executor2);
    executeData = abi.encodePacked(
      abi.encodeWithSelector(account.claimExecutorPermission.selector),
      bytes32(uint256(0x1234)),
      uint256(1),
      imposter
    );
    vm.expectRevert(abi.encodeWithSelector(OriginSenderNotOwner.selector, imposter));
    address(account).call(executeData);
    vm.stopPrank();
  }
}
