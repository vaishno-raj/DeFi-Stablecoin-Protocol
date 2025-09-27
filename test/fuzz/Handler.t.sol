
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import{DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mock/ERC20Mock.sol";


contract Handler is Test {
 DSCEngine dsce;
 DecentralizedStableCoin dsc;
  
 ERC20Mock weth;
 ERC20Mock wbtc;
 uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

 uint256 public timesMintIsCalled;
 address[] usersWithCollateralDeposited;
 uint256 public timesMintCalled;


 constructor(DSCEngine _engine, DecentralizedStableCoin _dsc){
  dsce = _engine;
  dsc = _dsc;

  address[] memory collateralToken = dsce.getCollateralTokens();
   weth = ERC20Mock(collateralToken[0]);
   wbtc = ERC20Mock(collateralToken[1]);

 }


 function depositeCollateral(uint256  collateralSeed, uint256 amountCollateral) public {
  ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
  amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
  

  // mint and approval

  vm.startPrank(msg.sender);
  collateral.mint(msg.sender, amountCollateral);
  collateral.approve(address(dsce),amountCollateral);

  dsce.depositCollateral(address(collateral),amountCollateral);
  vm.stopPrank();

  usersWithCollateralDeposited.push(msg.sender);
 }


 function mintDsc(uint256 amount,uint256 addressSeed) public {
    if(usersWithCollateralDeposited.length ==0){
        return;
    }
 address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];

 (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(msg.sender);
  
  uint256 maxDscToMint = (collateralValueInUsd/2)-totalDscMinted;
 if(maxDscToMint<0){
    return;
 }

 amount = bound(amount, 0, maxDscToMint);
 if(amount<0){
  return;
 }

 vm.startPrank(msg.sender);
 dsce.mintDsc(amount);
 vm.stopPrank();
  timesMintCalled++;

 
 }

 function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
 ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
 uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(address(collateral),msg.sender);

 amountCollateral = bound(amountCollateral, 0,maxCollateralToRedeem );
 if(amountCollateral==0){
    revert("cannot redeem 0 collateral") ;
 }
 dsce.redeemedCollateral(address(collateral), amountCollateral);



 }



 function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock){
  if(collateralSeed %2 == 0){
    return weth;
  }
  return wbtc;

 }




}