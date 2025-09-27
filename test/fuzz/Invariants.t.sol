

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";


import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
DeployDSC deployer;
DSCEngine dsce;
DecentralizedStableCoin dsc;
HelperConfig helperConfig;
Handler handler;
address weth;
address wbtc;


function setUp() external {
    deployer = new DeployDSC();
    (dsc,dsce,helperConfig) = deployer.run();
 ( , ,weth,wbtc,) = helperConfig.activeNetworkConfig();
  handler = new Handler(dsce, dsc);
  targetContract(address(handler));

}

function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
 
 uint256 totalSupply = dsc.totalSupply();
 
 uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
 uint256 totalWbtcDeposited  = IERC20(wbtc).balanceOf(address(dsce));

 uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
 uint256 wbtcValue = dsce.getUsdValue(wbtc, totalWbtcDeposited);
   
    console.log("Times mint called:", handler.timesMintCalled());
    console.log("Total supply:", totalSupply);



 assert(wethValue+wbtcValue >= totalSupply);

}





}