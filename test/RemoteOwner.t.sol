// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";


import {
  RemoteOwner,
  OriginChainIdZero,
  LocalSenderNotExecutor,
  OriginChainIdUnsupported,
  OriginSenderNotOwner,
  OriginChainOwnerZeroAddress,
  CallFailed
} from "../src/RemoteOwner.sol";

import { RemoteOwnerCallEncoder } from "../src/libraries/RemoteOwnerCallEncoder.sol";

/// @dev See the "Writing Tests" section in the Foundry Book if this is your first time with Forge.
/// https://book.getfoundry.sh/forge/writing-tests
contract RemoteOwnerTest is Test {
  
  RemoteOwner account;

  address originChainOwner;

  address imposter;

  address recipient;

  bytes recipientCalldata;
  bytes executeData;

  function setUp() public {
    originChainOwner = makeAddr("originChainOwner");
    imposter = makeAddr("imposter");

    account = new RemoteOwner(1, address(this), originChainOwner);

    recipient = makeAddr("recipient");
    vm.etch(recipient, "recipient");
    recipientCalldata = abi.encodeWithSignature("getValue(uint256)", 42);
    vm.mockCall(recipient, recipientCalldata, abi.encode(1000));

    executeData = abi.encodePacked(RemoteOwnerCallEncoder.encodeCalldata(recipient, 0, recipientCalldata), bytes32(uint256(0x1234)), uint256(1), originChainOwner);
  }

  function testConstructor() public {
    assertEq(account.originChainId(), 1);
    assertEq(account.originChainOwner(), originChainOwner);
  }

  function testConstructor_OriginChainIdZero() public {
    vm.expectRevert(abi.encodeWithSelector(OriginChainIdZero.selector));
    new RemoteOwner(0, address(this), originChainOwner);
  }

  function testConstructor_ExecutorZeroAddress() public {
    vm.expectRevert("executor-not-zero-address");
    new RemoteOwner(1, address(0), originChainOwner);
  }

  function testConstructor_OriginChainOwnerZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(OriginChainOwnerZeroAddress.selector));
    new RemoteOwner(1, address(this), address(0));
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
    executeData = abi.encodePacked(abi.encodeWithSelector(account.execute.selector, recipient, 0, recipientCalldata), bytes32(uint256(0x1234)), uint256(2), originChainOwner);
    vm.expectRevert(abi.encodeWithSelector(OriginChainIdUnsupported.selector, 2));
    address(account).call(executeData);
  }

  function testExecute_OriginSenderNotOwner() public {
    executeData = abi.encodePacked(abi.encodeWithSelector(account.execute.selector, recipient, 0, recipientCalldata), bytes32(uint256(0x1234)), uint256(1), imposter);
    vm.expectRevert(abi.encodeWithSelector(OriginSenderNotOwner.selector, imposter));
    address(account).call(executeData);
  }

  function testSetOriginChainOwner() public {
    executeData = abi.encodePacked(abi.encodeWithSelector(account.setOriginChainOwner.selector, imposter), bytes32(uint256(0x1234)), uint256(1), originChainOwner);
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertTrue(success, "was successful");
    assertEq(account.originChainOwner(), imposter);
  }

  function testSetOriginChainOwner_invalidSender() public {
    executeData = abi.encodePacked(abi.encodeWithSelector(account.setOriginChainOwner.selector, imposter), bytes32(uint256(0x1234)), uint256(1), imposter);
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertFalse(success, "failed");
    assertEq(returnData, abi.encodeWithSelector(OriginSenderNotOwner.selector, imposter));
  }

  function testSetOriginChainOwner_newOwnerZeroAddress() public {
    executeData = abi.encodePacked(abi.encodeWithSelector(account.setOriginChainOwner.selector, address(0)), bytes32(uint256(0x1234)), uint256(1), originChainOwner);
    (bool success, bytes memory returnData) = address(account).call(executeData);
    assertFalse(success, "failed");
    assertEq(returnData, abi.encodeWithSelector(OriginChainOwnerZeroAddress.selector));
  }

}
