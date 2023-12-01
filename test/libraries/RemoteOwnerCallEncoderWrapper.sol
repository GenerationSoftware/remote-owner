// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RemoteOwnerCallEncoder } from "../../src/libraries/RemoteOwnerCallEncoder.sol";

contract RemoteOwnerCallEncoderWrapper {
  function encodeCalldata(
    address target,
    uint256 value,
    bytes memory data
  ) external pure returns (bytes memory) {
    bytes memory result = RemoteOwnerCallEncoder.encodeCalldata(target, value, data);
    return result;
  }
}
