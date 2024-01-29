// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {IReceiptToken} from "../src/interfaces/IReceiptToken.sol";
import {IReceiptTokenFactory} from "../src/interfaces/IReceiptTokenFactory.sol";
import {ReceiptToken} from "../src/ReceiptToken.sol";
import {ReceiptTokenFactory} from "../src/ReceiptTokenFactory.sol";
import {TestBase} from "./utils/TestBase.sol";

contract ReceiptTokenFactoryTest is TestBase {
  ReceiptToken depositReceiptTokenLogic;
  ReceiptToken stkReceiptTokenLogic;
  ReceiptTokenFactory receiptTokenFactory;

  address mockSafetyModule = _randomAddress();

  /// @dev Emitted when a new ReceiptToken is deployed.
  event ReceiptTokenDeployed(
    IReceiptToken receiptToken,
    address indexed module,
    uint16 indexed poolId,
    IReceiptTokenFactory.PoolType indexed poolType,
    uint8 decimals_
  );

  function setUp() public {
    depositReceiptTokenLogic = new ReceiptToken();
    stkReceiptTokenLogic = new ReceiptToken();

    receiptTokenFactory = new ReceiptTokenFactory(
      IReceiptToken(address(depositReceiptTokenLogic)), IReceiptToken(address(stkReceiptTokenLogic))
    );
  }

  function test_deployReceiptTokenFactory() public {
    assertEq(address(receiptTokenFactory.depositReceiptTokenLogic()), address(depositReceiptTokenLogic));
    assertEq(address(receiptTokenFactory.stkReceiptTokenLogic()), address(stkReceiptTokenLogic));
  }

  function test_RevertDeployReceiptTokenFactoryZeroAddressLogicContracts() public {
    vm.expectRevert(ReceiptTokenFactory.InvalidAddress.selector);
    new ReceiptTokenFactory(IReceiptToken(address(0)), IReceiptToken(address(stkReceiptTokenLogic)));

    vm.expectRevert(ReceiptTokenFactory.InvalidAddress.selector);
    new ReceiptTokenFactory(IReceiptToken(address(depositReceiptTokenLogic)), IReceiptToken(address(0)));

    vm.expectRevert(ReceiptTokenFactory.InvalidAddress.selector);
    new ReceiptTokenFactory(IReceiptToken(address(0)), IReceiptToken(address(0)));
  }

  function test_deployDepositToken() public {
    uint16 poolId_ = _randomUint16();
    uint8 decimals_ = _randomUint8();

    address computedReserveDepositTokenAddress_ =
      receiptTokenFactory.computeAddress(mockSafetyModule, poolId_, IReceiptTokenFactory.PoolType.RESERVE);

    _expectEmit();
    emit ReceiptTokenDeployed(
      IReceiptToken(computedReserveDepositTokenAddress_),
      mockSafetyModule,
      poolId_,
      IReceiptTokenFactory.PoolType.RESERVE,
      decimals_
    );
    vm.prank(address(mockSafetyModule));
    IReceiptToken reserveDepositToken_ =
      receiptTokenFactory.deployReceiptToken(poolId_, IReceiptTokenFactory.PoolType.RESERVE, decimals_);

    assertEq(address(reserveDepositToken_), computedReserveDepositTokenAddress_);
    assertEq(address(reserveDepositToken_.module()), address(mockSafetyModule));
    assertEq(reserveDepositToken_.name(), "Cozy Reserve Deposit Token");
    assertEq(reserveDepositToken_.symbol(), "cozyDep");

    address computedRewardDepositTokenAddress_ =
      receiptTokenFactory.computeAddress(mockSafetyModule, poolId_, IReceiptTokenFactory.PoolType.REWARD);

    emit ReceiptTokenDeployed(
      IReceiptToken(computedRewardDepositTokenAddress_),
      mockSafetyModule,
      poolId_,
      IReceiptTokenFactory.PoolType.REWARD,
      decimals_
    );
    vm.prank(address(mockSafetyModule));
    IReceiptToken rewardDepositToken_ =
      receiptTokenFactory.deployReceiptToken(poolId_, IReceiptTokenFactory.PoolType.REWARD, decimals_);

    assertEq(address(rewardDepositToken_), computedRewardDepositTokenAddress_);
    assertEq(address(rewardDepositToken_.module()), address(mockSafetyModule));
    assertEq(rewardDepositToken_.name(), "Cozy Reward Deposit Token");
    assertEq(rewardDepositToken_.symbol(), "cozyDep");

    address computedStkTokenAddress_ =
      receiptTokenFactory.computeAddress(mockSafetyModule, poolId_, IReceiptTokenFactory.PoolType.STAKE);

    emit ReceiptTokenDeployed(
      IReceiptToken(computedStkTokenAddress_), mockSafetyModule, poolId_, IReceiptTokenFactory.PoolType.STAKE, decimals_
    );
    vm.prank(address(mockSafetyModule));
    IReceiptToken stkToken_ =
      receiptTokenFactory.deployReceiptToken(poolId_, IReceiptTokenFactory.PoolType.STAKE, decimals_);

    assertEq(address(stkToken_), computedStkTokenAddress_);
    assertEq(address(stkToken_.module()), address(mockSafetyModule));
    assertEq(stkToken_.name(), "Cozy Stake Token");
    assertEq(stkToken_.symbol(), "cozyStk");
  }
}

// ---------------------------------------------------
// -------- General ERC-20 tests from Solmate --------
// ---------------------------------------------------

contract SolmatePTokenTest is TestBase {
  address self = address(this);

  bytes32 constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

  ReceiptToken tokenA;
  address module = _randomAddress();

  function setUp() public {
    tokenA = new ReceiptToken();
    tokenA.initialize(module, "TEST NAME", "TEST", 6);
  }

  // Next we have tests for our mint restrictions (successful mints are tests by Solmate below).
  function test_RevertMint() public {
    testFuzz_RevertMint(address(0xBEEF), 2500 ether, address(0xFACE));
  }

  function testFuzz_RevertMint(address to_, uint216 amount_, address caller_) public {
    vm.assume(caller_ != address(tokenA.module()));
    vm.prank(caller_);
    vm.expectRevert(ReceiptToken.Unauthorized.selector);
    tokenA.mint(to_, amount_);
  }

  // Then we have the tests from Solmate.
  function test_InvariantMetadata() public {
    assertEq(tokenA.name(), "TEST NAME");
    assertEq(tokenA.symbol(), "TEST");
    assertEq(tokenA.decimals(), 6);
  }

  function test_Mint() public {
    vm.startPrank(address(tokenA.module()));
    tokenA.mint(address(0xBEEF), 1e18);
    skip(ONE_YEAR); // Skip forward to ensure all protection is matured.

    assertEq(tokenA.totalSupply(), 1e18);
    assertEq(tokenA.balanceOf(address(0xBEEF)), 1e18);
  }

  function test_Burn() public {
    vm.startPrank(address(tokenA.module()));
    tokenA.mint(address(0xBEEF), 1e18);
    skip(ONE_YEAR); // Skip forward to ensure all protection is matured.
    tokenA.burn(address(0xBEEF), address(0xBEEF), 0.9e18);

    assertEq(tokenA.totalSupply(), 1e18 - 0.9e18);
    assertEq(tokenA.balanceOf(address(0xBEEF)), 0.1e18);
  }

  function test_Approve() public {
    assertTrue(tokenA.approve(address(0xBEEF), 1e18));

    assertEq(tokenA.allowance(address(this), address(0xBEEF)), 1e18);
  }

  function test_Transfer() public {
    vm.prank(address(tokenA.module()));
    tokenA.mint(self, 1e18);

    assertEq(tokenA.balanceOf(self), 1e18);
    assertEq(tokenA.balanceOf(address(0xBEEF)), 0);

    assertTrue(tokenA.transfer(address(0xBEEF), 1e18));
    assertEq(tokenA.totalSupply(), 1e18);

    assertEq(tokenA.balanceOf(self), 0);
    assertEq(tokenA.balanceOf(address(0xBEEF)), 1e18);
  }

  function test_TransferFrom() public {
    address from = address(0xABCD);

    vm.prank(address(tokenA.module()));
    tokenA.mint(from, 1e18);
    skip(ONE_YEAR); // Skip forward to ensure all protection is matured.

    vm.prank(from);
    tokenA.approve(address(this), 1e18);

    assertTrue(tokenA.transferFrom(from, address(0xBEEF), 1e18));
    assertEq(tokenA.totalSupply(), 1e18);

    assertEq(tokenA.allowance(from, address(this)), 0);

    assertEq(tokenA.balanceOf(from), 0);
    assertEq(tokenA.balanceOf(address(0xBEEF)), 1e18);
  }

  function test_InfiniteApproveTransferFrom() public {
    address from = address(0xABCD);

    vm.prank(module);
    tokenA.mint(from, 1e18);
    skip(ONE_YEAR); // Skip forward to ensure all protection is matured.

    vm.prank(from);
    tokenA.approve(address(this), type(uint256).max);

    assertTrue(tokenA.transferFrom(from, address(0xBEEF), 1e18));
    assertEq(tokenA.totalSupply(), 1e18);

    assertEq(tokenA.allowance(from, address(this)), type(uint256).max);

    assertEq(tokenA.balanceOf(from), 0);
    assertEq(tokenA.balanceOf(address(0xBEEF)), 1e18);
  }

  function test_Permit() public {
    uint256 privateKey = 0xBEEF;
    address owner = vm.addr(privateKey);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKey,
      keccak256(
        abi.encodePacked(
          "\x19\x01",
          tokenA.DOMAIN_SEPARATOR(),
          keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
        )
      )
    );

    tokenA.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);

    assertEq(tokenA.allowance(owner, address(0xCAFE)), 1e18);
    assertEq(tokenA.nonces(owner), 1);
  }

  function testFail_TransferInsufficientBalance() public {
    vm.prank(module);
    tokenA.mint(address(this), 0.9e18);
    tokenA.transfer(address(0xBEEF), 1e18);
  }

  function testFail_TransferFromInsufficientAllowance() public {
    address from = address(0xABCD);

    vm.prank(module);
    tokenA.mint(from, 1e18);

    vm.prank(from);
    tokenA.approve(address(this), 0.9e18);

    tokenA.transferFrom(from, address(0xBEEF), 1e18);
  }

  function testFail_TransferFromInsufficientBalance() public {
    address from = address(0xABCD);

    vm.prank(module);
    tokenA.mint(from, 0.9e18);

    vm.prank(from);
    tokenA.approve(address(this), 1e18);

    tokenA.transferFrom(from, address(0xBEEF), 1e18);
  }

  function testFail_PermitBadNonce() public {
    uint256 privateKey = 0xBEEF;
    address owner = vm.addr(privateKey);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKey,
      keccak256(
        abi.encodePacked(
          "\x19\x01",
          tokenA.DOMAIN_SEPARATOR(),
          keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 1, block.timestamp))
        )
      )
    );

    tokenA.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
  }

  function testFail_PermitBadDeadline() public {
    uint256 privateKey = 0xBEEF;
    address owner = vm.addr(privateKey);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKey,
      keccak256(
        abi.encodePacked(
          "\x19\x01",
          tokenA.DOMAIN_SEPARATOR(),
          keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
        )
      )
    );

    tokenA.permit(owner, address(0xCAFE), 1e18, block.timestamp + 1, v, r, s);
  }

  function testFail_PermitPastDeadline() public {
    uint256 privateKey = 0xBEEF;
    address owner = vm.addr(privateKey);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKey,
      keccak256(
        abi.encodePacked(
          "\x19\x01",
          tokenA.DOMAIN_SEPARATOR(),
          keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp - 1))
        )
      )
    );

    tokenA.permit(owner, address(0xCAFE), 1e18, block.timestamp - 1, v, r, s);
  }

  function testFail_PermitReplay() public {
    uint256 privateKey = 0xBEEF;
    address owner = vm.addr(privateKey);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKey,
      keccak256(
        abi.encodePacked(
          "\x19\x01",
          tokenA.DOMAIN_SEPARATOR(),
          keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
        )
      )
    );

    tokenA.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    tokenA.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
  }

  function test_Metadata(uint8 decimals) public {
    ReceiptToken tkn = new ReceiptToken();
    tkn.initialize(module, "TEST NAME", "TEST", decimals);
    assertEq(tkn.decimals(), decimals);
  }

  function test_Mint(address from, uint128 amount) public {
    vm.prank(address(tokenA.module()));
    tokenA.mint(from, amount);
    skip(ONE_YEAR); // Skip forward to ensure all protection is matured.

    assertEq(tokenA.totalSupply(), amount);
    assertEq(tokenA.balanceOf(from), amount);
  }

  function test_Burn(address from, uint216 mintAmount, uint216 burnAmount) public {
    mintAmount = uint216(bound(mintAmount, 0, type(uint216).max));
    burnAmount = uint216(bound(burnAmount, 0, mintAmount));

    vm.startPrank(address(tokenA.module()));
    tokenA.mint(from, mintAmount);
    skip(ONE_YEAR); // Skip forward to ensure all protection is matured.
    tokenA.burn(from, from, burnAmount);
    vm.stopPrank();

    assertEq(tokenA.totalSupply(), mintAmount - burnAmount);
    assertEq(tokenA.balanceOf(from), mintAmount - burnAmount);
  }

  function test_Approve(address to, uint256 amount) public {
    assertTrue(tokenA.approve(to, amount));

    assertEq(tokenA.allowance(address(this), to), amount);
  }

  function test_Transfer(address from, uint128 amount) public {
    vm.prank(address(tokenA.module()));
    tokenA.mint(address(this), amount);
    skip(ONE_YEAR); // Skip forward to ensure all protection is matured.

    assertTrue(tokenA.transfer(from, amount));
    assertEq(tokenA.totalSupply(), amount);

    if (address(this) == from) {
      assertEq(tokenA.balanceOf(address(this)), amount);
    } else {
      assertEq(tokenA.balanceOf(address(this)), 0);
      assertEq(tokenA.balanceOf(from), amount);
    }
  }

  function test_TransferFrom(address to, uint216 approval, uint216 amount) public {
    approval = uint216(bound(approval, 0, type(uint216).max));
    amount = uint216(bound(amount, 0, approval));

    address from = address(0xABCD);

    vm.prank(address(tokenA.module()));
    tokenA.mint(from, amount);
    skip(ONE_YEAR); // Skip forward to ensure all protection is matured.

    vm.prank(from);
    tokenA.approve(address(this), approval);

    assertTrue(tokenA.transferFrom(from, to, amount));
    assertEq(tokenA.totalSupply(), amount);

    uint256 app = from == address(this) || approval == type(uint256).max ? approval : approval - amount;
    assertEq(tokenA.allowance(from, address(this)), app);

    if (from == to) {
      assertEq(tokenA.balanceOf(from), amount);
    } else {
      assertEq(tokenA.balanceOf(from), 0);
      assertEq(tokenA.balanceOf(to), amount);
    }
  }

  function test_Permit(uint248 privKey, address to, uint256 amount, uint256 deadline) public {
    uint256 privateKey = privKey;
    if (deadline < block.timestamp) deadline = block.timestamp;
    if (privateKey == 0) privateKey = 1;

    address owner = vm.addr(privateKey);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKey,
      keccak256(
        abi.encodePacked(
          "\x19\x01", tokenA.DOMAIN_SEPARATOR(), keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
        )
      )
    );

    tokenA.permit(owner, to, amount, deadline, v, r, s);

    assertEq(tokenA.allowance(owner, to), amount);
    assertEq(tokenA.nonces(owner), 1);
  }

  // function testFail_BurnInsufficientBalance(address to, uint216 mintAmount, uint256 burnAmount) public {
  //   burnAmount = bound(burnAmount, mintAmount + 1, type(uint256).max);

  //   tokenA.mint(to, mintAmount);
  //   tokenA.burn(to, burnAmount);
  // }

  function testFail_TransferInsufficientBalance(address to, uint216 mintAmount, uint256 sendAmount) public {
    sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

    tokenA.mint(address(this), mintAmount);
    tokenA.transfer(to, sendAmount);
  }

  function testFail_TransferFromInsufficientAllowance(address to, uint216 approval, uint216 amount) public {
    amount = uint216(bound(amount, approval + 1, type(uint216).max));

    address from = address(0xABCD);

    tokenA.mint(from, amount);

    vm.prank(from);
    tokenA.approve(address(this), approval);

    tokenA.transferFrom(from, to, amount);
  }

  function testFail_TransferFromInsufficientBalance(address to, uint216 mintAmount, uint256 sendAmount) public {
    sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

    address from = address(0xABCD);

    tokenA.mint(from, mintAmount);

    vm.prank(from);
    tokenA.approve(address(this), sendAmount);

    tokenA.transferFrom(from, to, sendAmount);
  }

  function testFail_PermitBadNonce(uint256 privateKey, address to, uint256 amount, uint256 deadline, uint256 nonce)
    public
  {
    if (deadline < block.timestamp) deadline = block.timestamp;
    if (privateKey == 0) privateKey = 1;
    if (nonce == 0) nonce = 1;

    address owner = vm.addr(privateKey);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKey,
      keccak256(
        abi.encodePacked(
          "\x19\x01",
          tokenA.DOMAIN_SEPARATOR(),
          keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, nonce, deadline))
        )
      )
    );

    tokenA.permit(owner, to, amount, deadline, v, r, s);
  }

  function testFail_PermitBadDeadline(uint256 privateKey, address to, uint256 amount, uint256 deadline) public {
    if (deadline < block.timestamp) deadline = block.timestamp;
    if (privateKey == 0) privateKey = 1;

    address owner = vm.addr(privateKey);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKey,
      keccak256(
        abi.encodePacked(
          "\x19\x01", tokenA.DOMAIN_SEPARATOR(), keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
        )
      )
    );

    tokenA.permit(owner, to, amount, deadline + 1, v, r, s);
  }

  function testFail_PermitPastDeadline(uint256 privateKey, address to, uint256 amount, uint256 deadline) public {
    deadline = bound(deadline, 0, block.timestamp - 1);
    if (privateKey == 0) privateKey = 1;

    address owner = vm.addr(privateKey);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKey,
      keccak256(
        abi.encodePacked(
          "\x19\x01", tokenA.DOMAIN_SEPARATOR(), keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
        )
      )
    );

    tokenA.permit(owner, to, amount, deadline, v, r, s);
  }

  function testFail_PermitReplay(uint256 privateKey, address to, uint256 amount, uint256 deadline) public {
    if (deadline < block.timestamp) deadline = block.timestamp;
    if (privateKey == 0) privateKey = 1;

    address owner = vm.addr(privateKey);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKey,
      keccak256(
        abi.encodePacked(
          "\x19\x01", tokenA.DOMAIN_SEPARATOR(), keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
        )
      )
    );

    tokenA.permit(owner, to, amount, deadline, v, r, s);
    tokenA.permit(owner, to, amount, deadline, v, r, s);
  }
}
