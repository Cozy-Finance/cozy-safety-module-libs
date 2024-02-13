// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface IDripModel {
  /// @notice Returns the drip factor, given the `lastDripTime_`.
  function dripFactor(uint256 lastDripTime_) external view returns (uint256 dripFactor_);
}
