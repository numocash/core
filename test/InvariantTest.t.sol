// pragma solidity ^0.8.4;

// import "forge-std/console2.sol";

// import { TestHelper } from "./utils/TestHelper.sol";
// import { CallbackHelper } from "./utils/CallbackHelper.sol";
// import { ERC20 } from "solmate/tokens/ERC20.sol";

// import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";

// import { Factory } from "../src/Factory.sol";
// import { Lendgine } from "../src/Lendgine.sol";
// import { Pair } from "../src/Pair.sol";
// import { Math } from "../src/libraries/Math.sol";

// contract InvariantTest is TestHelper {
//     function setUp() public {
//         _setUp();
//     }

//     function testLiquidityAmount() public {
//         _pairMint(9 ether, 4 ether, 1 ether, cuh);

//         assertEq(pair.totalSupply(), 1 ether);
//         assertEq(pair.buffer(), 1 ether);
//     }

//     function testBaseUpperBound() public {
//         _pairMint(25 ether, 0, 1 ether, cuh);
//     }

//     function testSpeculativeUpperBound() public {
//         _pairMint(0 ether, 2 * upperBound, 1 ether, cuh);
//     }

//     function testTooLargeScale() public {
//         base.mint(cuh, 9 ether);
//         speculative.mint(cuh, 4 ether);

//         vm.prank(cuh);
//         base.approve(address(this), 9 ether);

//         vm.prank(cuh);
//         speculative.approve(address(this), 4 ether);

//         vm.expectRevert(Pair.InvariantError.selector);
//         pair.mint(9 ether, 4 ether, 1 ether + 1, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));
//     }

//     function testTooSmallScale() public {
//         base.mint(cuh, 9 ether);
//         speculative.mint(cuh, 4 ether);

//         vm.prank(cuh);
//         base.approve(address(this), 9 ether);

//         vm.prank(cuh);
//         speculative.approve(address(this), 4 ether);

//         vm.expectRevert(Pair.InvariantError.selector);
//         pair.mint(9 ether, 4 ether, 1 ether - 1, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));
//     }

//     function testSpeculativeUpperBound2() public {
//         _pairMint(0 ether, 10 ether, 1 ether, cuh);
//     }

//     function testLargeScale() public {
//         _pairMint(10**27, 8 * 10**27, 10**27, cuh);
//     }

//     function testSmallScale() public {
//         _pairMint(1_000_000, 8_000_000, 1_000_000, cuh);
//     }

//     function testDivideToZero() public {
//         base.mint(cuh, 9 ether);
//         speculative.mint(cuh, 4 ether);

//         vm.prank(cuh);
//         base.approve(address(this), 9 ether);

//         vm.prank(cuh);
//         speculative.approve(address(this), 4 ether);

//         vm.expectRevert(Pair.InvariantError.selector);
//         pair.mint(
//             9 ether,
//             4 ether,
//             1 ether * 1 ether,
//             abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh }))
//         );
//     }

//     function testDivideByZero() public {
//         base.mint(cuh, 9 ether);
//         speculative.mint(cuh, 4 ether);

//         vm.prank(cuh);
//         base.approve(address(this), 9 ether);

//         vm.prank(cuh);
//         speculative.approve(address(this), 4 ether);

//         vm.expectRevert(Pair.InsufficientOutputError.selector);
//         pair.mint(9 ether, 4 ether, 0, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));
//     }

//     function testSpeculativeInvariantError() public {
//         speculative.mint(cuh, 2 * upperBound + 1);

//         vm.prank(cuh);
//         speculative.approve(address(this), 2 * upperBound + 1);

//         vm.expectRevert(Pair.SpeculativeInvariantError.selector);
//         pair.mint(0, 2 * upperBound + 1, 1 ether, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));
//     }

//     function testBaseInvariantError() public {
//         base.mint(cuh, 25 ether + 1);

//         vm.prank(cuh);
//         base.approve(address(this), 25 ether + 1);

//         vm.expectRevert(Pair.BaseInvariantError.selector);
//         pair.mint(25 ether + 1, 0, 1 ether, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));
//     }

//     function testBurnAmount() public {
//         _pairMint(9 ether, 4 ether, 1 ether, cuh);

//         pair.burn(cuh);

//         assertEq(base.balanceOf(cuh), 9 ether);
//         assertEq(speculative.balanceOf(cuh), 4 ether);

//         assertEq(pair.totalSupply(), 0);
//         assertEq(pair.buffer(), 0);
//     }

//     function testDouble() public {
//         _mintMaker(1 ether, 8 ether, 1 ether, 1, cuh);
//         _pairMint(1_000_000, 8_000_000, 1_000_000, dennis);

//         assertEq(pair.totalSupply(), 1 ether + 1_000_000);
//         assertEq(pair.buffer(), 1_000_000);

//         pair.burn(dennis);

//         assertEq(base.balanceOf(dennis), 1_000_000);
//         assertEq(speculative.balanceOf(dennis), 8_000_000);

//         assertEq(pair.buffer(), 0);
//         assertEq(pair.totalSupply(), 1 ether);

//         _burnMaker(1 ether, 1, cuh);

//         assertEq(pair.buffer(), 1 ether);
//         assertEq(pair.totalSupply(), 1 ether);

//         pair.burn(cuh);

//         assertEq(pair.totalSupply(), 0);
//         assertEq(pair.buffer(), 0);

//         assertEq(base.balanceOf(cuh), 1 ether);
//         assertEq(speculative.balanceOf(cuh), 8 ether);
//     }

//     struct SwapCallbackData {
//         LendgineAddress.LendgineKey key;
//         address payer;
//         uint256 amount0In;
//         uint256 amount1In;
//     }

//     function SwapCallback(
//         uint256,
//         uint256,
//         bytes calldata data
//     ) external {
//         SwapCallbackData memory decoded = abi.decode(data, (SwapCallbackData));
//         // CallbackValidation.verifyCallback(factory, decoded.poolKey);

//         if (decoded.amount0In > 0) pay(ERC20(decoded.key.base), decoded.payer, msg.sender, decoded.amount0In);
//         if (decoded.amount1In > 0) pay(ERC20(decoded.key.speculative), decoded.payer, msg.sender, decoded.amount1In);
//     }

//     function testSwapBForS1() public {
//         uint256 rB = 1 ether;
//         uint256 rS = 8 ether;
//         _pairMint(rB, rS, 1 ether, cuh);

//         uint256 amountSOut = 0.00001 ether;

//         uint256 a = (amountSOut * upperBound) / 10**18;

//         uint256 b = (amountSOut**2) / 4 ether;

//         uint256 c = (amountSOut * rS) / 2 ether;

//         uint256 amountBIn = a + b - c;

//         base.mint(cuh, amountBIn);

//         vm.prank(cuh);
//         base.approve(address(this), amountBIn);

//         console2.log("quote price", 1 ether);
//         console2.log("trade price", (amountBIn * 1 ether) / amountSOut);

//         pair.swap(
//             cuh,
//             0,
//             amountSOut,
//             abi.encode(SwapCallbackData({ key: key, payer: cuh, amount0In: amountBIn, amount1In: 0 }))
//         );
//     }

//     // function testSwapBForS2() public {
//     //     uint256 rB = 0 ether;
//     //     uint256 rS = 4 ether;
//     //     _pairMint(rB, rS, cuh);

//     //     uint256 amountBIn = 0.00001 ether;

//     //     uint256 a = rS + 2 * upperBound;

//     //     uint256 b = 4 * amountBIn * 1 ether;

//     //     uint256 c = Math.sqrt(b + a**2);

//     //     uint256 amountSOut = a + c;

//     //     base.mint(cuh, amountBIn);

//     //     console2.log("base in", amountBIn);
//     //     console2.log("spec out", amountSOut);

//     //     console2.log("IB", pair.calcInvariant(rB, rS));
//     //     // console2.log("IA", pair.calcInvariant(rB + , r1);)

//     //     vm.prank(cuh);
//     //     base.approve(address(this), amountBIn);

//     //     pair.swap(
//     //         cuh,
//     //         0,
//     //         amountSOut,
//     //         abi.encode(SwapCallbackData({ key: key, payer: cuh, amount0In: amountBIn, amount1In: 0 }))
//     //     );
//     // }

//     function testSwapUpperBound() public {
//         uint256 rB = 0 ether;
//         uint256 rS = 2 ether;
//         _pairMint(rB, rS, 1 ether / 5, cuh);

//         uint256 amountSOut = 2 ether;

//         uint256 amountBIn = 5 ether;

//         base.mint(cuh, amountBIn);

//         vm.prank(cuh);
//         base.approve(address(this), amountBIn);

//         pair.swap(
//             cuh,
//             0,
//             amountSOut,
//             abi.encode(SwapCallbackData({ key: key, payer: cuh, amount0In: amountBIn, amount1In: 0 }))
//         );

//         (uint256 balanceBase, uint256 balanceSpec) = pair.balances();

//         assertEq(balanceBase, amountBIn);
//         assertEq(balanceSpec, 0);
//     }

//     function testBurnWithDonation() public {
//         _pairMint(9 ether, 4 ether, 1 ether, cuh);

//         base.mint(dennis, 9 ether);
//         speculative.mint(dennis, 4 ether);

//         vm.startPrank(dennis);
//         base.transfer(address(pair), 9 ether);
//         speculative.transfer(address(pair), 4 ether);
//         vm.stopPrank();

//         pair.burn(cuh);

//         assertEq(base.balanceOf(cuh), 18 ether);
//         assertEq(speculative.balanceOf(cuh), 8 ether);

//         assertEq(pair.totalSupply(), 0);
//         assertEq(pair.buffer(), 0);
//     }

//     function testBurnDoubleWithDonation() public {
//         _mintMaker(9 ether, 4 ether, 1 ether, 1, cuh);

//         base.mint(address(pair), 9 ether);
//         speculative.mint(address(pair), 4 ether);

//         _pairMint(9 ether, 4 ether, 1 ether, dennis);

//         pair.burn(dennis);

//         assertEq(base.balanceOf(dennis), 13.5 ether);
//         assertEq(speculative.balanceOf(dennis), 6 ether);

//         assertEq(pair.totalSupply(), 1 ether);
//         assertEq(pair.buffer(), 0);

//         _burnMaker(1 ether, 1, cuh);

//         assertEq(pair.buffer(), 1 ether);
//         assertEq(pair.totalSupply(), 1 ether);

//         pair.burn(cuh);

//         assertEq(pair.totalSupply(), 0);
//         assertEq(pair.buffer(), 0);

//         assertEq(base.balanceOf(cuh), 13.5 ether);
//         assertEq(speculative.balanceOf(cuh), 6 ether);
//     }

//     function testSwapWithDonations() public {
//         _pairMint(1 ether, 8 ether, 1 ether, cuh);

//         base.mint(address(pair), 1_000_000);
//         speculative.mint(address(pair), 8_000_000);

//         uint256 amountSOut = 0.00001 ether;

//         uint256 a = (amountSOut * upperBound) / 10**18;

//         uint256 b = (amountSOut**2) / 4 ether;

//         uint256 c = (amountSOut * 8 ether) / 2 ether;

//         uint256 amountBIn = a + b - c;

//         base.mint(cuh, amountBIn);

//         vm.prank(cuh);
//         base.approve(address(this), amountBIn);

//         pair.swap(
//             cuh,
//             0,
//             amountSOut + 8_000_000,
//             abi.encode(SwapCallbackData({ key: key, payer: cuh, amount0In: amountBIn - 1_000_000, amount1In: 0 }))
//         );
//     }

//     // TODO: test precision with extremes price bounds (BTC / SHIB)

//     // How much in relative terms does a few lp positions cost
//     // How much liquidity can be added until an upper bound is reached
//     // concerns are the liquidity is so expensive that 1 wei is too much money for a regular person
//     // or that liquidity is so cheap that it starts to reach the max value

//     function testLPPriceLow() public {
//         uint256 price = 5 * 10**12;
//         uint256 r0 = price**2 / 1 ether;
//         uint256 r1 = 2 * (upperBound - price);
//         _pairMint(r0, r1, 1 ether, cuh);

//         uint256 value = r0 + (price * r1) / 1 ether;
//         console2.log("Max TVL of pool", value * 2**128);
//     }

//     function testLpPriceMax() public {
//         uint256 price = upperBound;
//         uint256 r0 = price**2 / 1 ether;
//         uint256 r1 = 2 * (upperBound - price);
//         _pairMint(r0, r1, 1 ether, cuh);

//         uint256 value = r0 + (price * r1) / 1 ether;
//         console2.log("price of LP ( Base * 10 ** 18)", value);
//     }

//     function testHighUpperBoundMax() public {
//         uint256 _upperBound = 10**30;

//         Lendgine _lendgine = Lendgine(factory.createLendgine(address(base), address(speculative), _upperBound));

//         Pair _pair = Pair(_lendgine.pair());

//         uint256 price = _upperBound;
//         uint256 r0 = price**2 / 1 ether;

//         base.mint(cuh, r0);

//         vm.prank(cuh);
//         base.approve(address(this), r0);

//         _pair.mint(r0, 0, 1 ether, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));

//         uint256 value = r0;
//         uint256 scale = 10**6;
//         console2.log("Dollars per LP token * 10**18", value / scale);
//     }

//     function testHighUpperBoundLow() public {
//         uint256 _upperBound = 10**30;

//         Lendgine _lendgine = Lendgine(factory.createLendgine(address(base), address(speculative), _upperBound));

//         Pair _pair = Pair(_lendgine.pair());

//         uint256 price = 10**24;
//         uint256 r0 = price**2 / 1 ether;
//         uint256 r1 = 2 * (_upperBound - price);

//         base.mint(cuh, r0);
//         speculative.mint(cuh, r1);

//         vm.prank(cuh);
//         base.approve(address(this), r0);
//         vm.prank(cuh);
//         speculative.approve(address(this), r1);

//         _pair.mint(r0, r1, 1 ether, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));

//         uint256 value = r0 + (price * r1) / 1 ether;
//         uint256 scale = 10**6;
//         console2.log("Max TVL of pool in $ * 10**18", (value * 2**128) / scale);
//     }

//     // function testLowUpperBoundMax() public {
//     //     uint256 _upperBound = 10**6;

//     //     Lendgine _lendgine = Lendgine(factory.createLendgine(address(base), address(speculative), _upperBound));

//     //     Pair _pair = Pair(_lendgine.pair());

//     //     uint256 price = _upperBound;
//     //     uint256 r0 = 1;

//     //     base.mint(cuh, r0);

//     //     vm.prank(cuh);
//     //     base.approve(address(this), r0);

//     //     _pair.mint(r0, 0, 10**15, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));

//     //     uint256 value = r0;
//     //     uint256 scale = 10**6;
//     //     console2.log("Dollars per LP token * 10**18", value / scale);
//     // }
// }
