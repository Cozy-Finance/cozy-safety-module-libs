// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {IReceiptToken} from "./interfaces/IReceiptToken.sol";
import {IReceiptTokenFactory} from "./interfaces/IReceiptTokenFactory.sol";

/**
 * @notice Deploys new deposit and stake receipt tokens, which implement the IReceiptToken interface.
 * @dev ReceiptTokens are compliant with ERC-20 and ERC-2612.
 */
contract ReceiptTokenFactory is IReceiptTokenFactory {
  using Clones for address;

  /// @notice Address of the deposit receipt token logic contract used to deploy new deposit receipt tokens.
  IReceiptToken public immutable depositReceiptTokenLogic;

  /// @notice Address of the stake receipt token logic contract used to deploy new stake receipt tokens.
  IReceiptToken public immutable stkReceiptTokenLogic;

  /// @dev Thrown if an address parameter is invalid.
  error InvalidAddress();

  /// @param depositReceiptTokenLogic_ Logic contract for deploying new deposit receipt tokens.
  /// @param stkReceiptTokenLogic_ Logic contract for deploying new stake receipt tokens.
  /// @dev stkReceiptTokens are only different from depositReceiptTokens in that they have special logic when they
  /// are transferred.
  constructor(IReceiptToken depositReceiptTokenLogic_, IReceiptToken stkReceiptTokenLogic_) {
    _assertAddressNotZero(address(depositReceiptTokenLogic_));
    _assertAddressNotZero(address(stkReceiptTokenLogic_));
    depositReceiptTokenLogic = depositReceiptTokenLogic_;
    stkReceiptTokenLogic = stkReceiptTokenLogic_;
  }

  /// @notice Creates a new ReceiptToken contract with the given number of `decimals_`. The ReceiptToken's safety /
  /// rewards module is identified by the caller address. The pool id of the ReceiptToken in the module and its
  /// `PoolType` is used to generate a unique salt for deploy.
  function deployReceiptToken(uint16 poolId_, PoolType poolType_, uint8 decimals_)
    external
    returns (IReceiptToken receiptToken_)
  {
    address tokenLogicContract_ =
      poolType_ == PoolType.STAKE ? address(stkReceiptTokenLogic) : address(depositReceiptTokenLogic);
    string memory name_ = poolType_ == PoolType.STAKE
      ? "Cozy Stake Token"
      : (poolType_ == PoolType.RESERVE ? "Cozy Reserve Deposit Token" : "Cozy Reward Deposit Token");
    string memory symbol_ = poolType_ == PoolType.STAKE ? "cozyStk" : "cozyDep";

    // We generate the salt from the module-pool id-pool type, which must be unique, and concatenate it with the
    // chain ID to prevent the same ReceiptToken address existing on multiple chains for different modules or
    // pools.
    receiptToken_ = IReceiptToken(address(tokenLogicContract_).cloneDeterministic(salt(msg.sender, poolId_, poolType_)));
    receiptToken_.initialize(msg.sender, name_, symbol_, decimals_);
    emit ReceiptTokenDeployed(receiptToken_, msg.sender, poolId_, poolType_, decimals_);
  }

  /// @notice Given a `module_`, its `poolId_`, and `poolType_`, compute and return the address of its
  /// ReceiptToken.
  function computeAddress(address module_, uint16 poolId_, PoolType poolType_) external view returns (address) {
    address tokenLogicContract_ =
      poolType_ == PoolType.STAKE ? address(stkReceiptTokenLogic) : address(depositReceiptTokenLogic);
    return Clones.predictDeterministicAddress(tokenLogicContract_, salt(module_, poolId_, poolType_), address(this));
  }

  /// @notice Given a `module_`, its `poolId_`, and `poolType_`, return the salt used to compute the ReceiptToken
  /// address.
  function salt(address module_, uint16 poolId_, PoolType poolType_) public view returns (bytes32) {
    return keccak256(abi.encode(module_, poolId_, poolType_, block.chainid));
  }

  /// @dev Revert if the address is the zero address.
  function _assertAddressNotZero(address address_) internal pure {
    if (address_ == address(0)) revert InvalidAddress();
  }
}
