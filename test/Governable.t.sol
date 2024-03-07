// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {Governable} from "../src/lib/Governable.sol";
import {TestBase} from "./utils/TestBase.sol";

contract GovernableHarness is Governable {
  function initGovernable(address owner_, address pauser_) external {
    __initGovernable(owner_, pauser_);
  }

  function updatePauser(address newPauser_) external {
    _updatePauser(newPauser_);
  }
}

contract GovernableTestSetup is TestBase {
  GovernableHarness governableHarness;

  /// @dev Emitted when the pauser address is updated.
  event PauserUpdated(address indexed newPauser_);

  function setUp() public virtual {
    governableHarness = new GovernableHarness();
  }

  function test_GovernableConstructor() public {
    assertEq(governableHarness.owner(), address(0));
    assertEq(governableHarness.pauser(), address(0));
  }

  function test_GovernableInit() public {
    address owner_ = _randomAddress();
    address pauser_ = _randomAddress();
    _expectEmit();
    emit PauserUpdated(pauser_);
    governableHarness.initGovernable(owner_, pauser_);
    assertEq(governableHarness.owner(), owner_);
    assertEq(governableHarness.pauser(), pauser_);
  }

  function test_UpdatePauser() public {
    address newPauser_ = _randomAddress();
    _expectEmit();
    emit PauserUpdated(newPauser_);
    vm.prank(address(0));
    governableHarness.updatePauser(newPauser_);
  }
}
