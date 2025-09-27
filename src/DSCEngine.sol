// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.20;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DecentralizedStableCoin } from "./DecentralizedStableCoin.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
 import{OracleLib} from "./libraries/OracleLib.sol";
/*
 * @title DSCEngine
 * @author vaishno raj
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
contract DSCEngine is ReentrancyGuard {
    //Errors//

    error DSCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine_NeedMoreThanZero();
    error DSCEngine_TokenNotAllowed(address token);
    error DSCEngine_TransferFailed();
     error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
     error  DSCEngine_MintFailed();
     error DSCEingine_HealthFactorOk();
     error  DSCEngine_HealthFactorNotImproved();

     // Types//
     using OracleLib for AggregatorV3Interface;

    //State variable//

    //address token=>address priceFeed

    mapping(address token => address priceFeed ) private s_priceFeeds;
    DecentralizedStableCoin private immutable i_dsc;
    mapping(address user=>mapping(address token=>uint256 amount)) private s_collateralDeposited;
    mapping(address user=>uint256 amountDscToMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD= 50;
    uint256 private constant LIQUIDATION_PRECISION= 100;
    uint256 private constant MIN_HEALTH_FACTOR=1e18;
     uint256 private constant LIQUIDATION_BONUS=10;

    //Event//

    event collateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event collateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo ,address indexed token, uint256 amount);

   //Modifier//

   modifier moreThanZero(uint256 amount){
    if(amount<=0){
        revert DSCEngine_NeedMoreThanZero();
    }
    _;
   }

   modifier isAllowedToken(address token){
    if(s_priceFeeds[token]==address(0)){
        revert DSCEngine_TokenNotAllowed( token);
    }
    _;
   }

   //Function//

   constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAdddress){
    if(tokenAddresses.length!= priceFeedAddresses.length){
        revert DSCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    }
    for(uint256 i=0; i<tokenAddresses.length;i++){
        s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        s_collateralTokens.push(tokenAddresses[i]);
    }
    i_dsc = DecentralizedStableCoin(dscAdddress);

   }




   function depositCollateral
   (address tokenCollateralAddress, uint256 amountCollateral) public
   moreThanZero(amountCollateral) nonReentrant isAllowedToken(tokenCollateralAddress)
   {
    s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
    emit collateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

    bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
     
     if(!success){
        revert DSCEngine_TransferFailed();
     }

   }


   /*
   *
   */
 // this function deposite collateral and mint function in one transaction 



 function depositCollateralAndMintDsc(
    address tokenCollateralAddress, uint256 amountCollateral
    ,uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);



 }


 function redeemedCollateralForDsc
 (address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn) 
 external{
 burnDsc(amountDscToBurn);
 redeemedCollateral(tokenCollateralAddress,amountCollateral);

 }



 function redeemedCollateral
 (address tokenCollateralAddress,uint256 amountCollateral) 
 public moreThanZero(amountCollateral) nonReentrant{
 _redeemCollateral(tokenCollateralAddress,amountCollateral, msg.sender,msg.sender);

  _revertIfHealthFactorIsBroken(msg.sender);

 } 


 
 function burnDsc(uint256 amount) public moreThanZero(amount){
 _burnDsc(amount,msg.sender,msg.sender);
 _revertIfHealthFactorIsBroken(msg.sender);
 }

 

 function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant{
 s_DSCMinted[msg.sender] += amountDscToMint;

 _revertIfHealthFactorIsBroken(msg.sender);

 bool minted = i_dsc.mint(msg.sender, amountDscToMint);
 if(!minted){
    revert DSCEngine_MintFailed();
 }

 }




 function liquidate
 (address collateral,address user,uint256 debtToCover )
 external moreThanZero(debtToCover) nonReentrant {

 uint256 startingUserHealthFactor = _healthFactor(user);
 if( startingUserHealthFactor> MIN_HEALTH_FACTOR){
    revert DSCEingine_HealthFactorOk();
 }
 uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral,debtToCover);

 uint256 bonusCollateral = (tokenAmountFromDebtCovered*LIQUIDATION_BONUS)/LIQUIDATION_PRECISION;

 uint256 totalCollateralRedeemed = tokenAmountFromDebtCovered+bonusCollateral;

 _redeemCollateral(collateral,totalCollateralRedeemed, user,msg.sender);

 _burnDsc(debtToCover,user,msg.sender);

 uint256 endingUserHealthFactor = _healthFactor(user);
 if(endingUserHealthFactor<=startingUserHealthFactor){
    revert DSCEngine_HealthFactorNotImproved();
 }
 _revertIfHealthFactorIsBroken(msg.sender);


 }





 function getHealthFactor() external view {}
 
 // Internal function

 function _revertIfHealthFactorIsBroken(address user) internal view {
  uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR){
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }




 }

 function _healthFactor(address user) private view returns(uint256){
    (uint256 totalDscMinted , uint256 collateralValueInUsd) = _getAccountInformation(user);
 
 return _calculateHealthFactor(totalDscMinted,collateralValueInUsd);

   


 }
 
 function _getAccountInformation(address user) private view returns(uint256 totalDscMinted, uint256 collateralValueInUsd){
 totalDscMinted = s_DSCMinted[user];
 collateralValueInUsd = _getAccountCollateralValue(user);

 }


 // public function 

 function _getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUsd){
  totalCollateralValueInUsd =0;

 for(uint256 i=0; i<s_collateralTokens.length; i++){
    address token = s_collateralTokens[i];
    uint256 amount = s_collateralDeposited[user][token];
    totalCollateralValueInUsd+= getUsdValue(token, amount);
 }
 return totalCollateralValueInUsd;

 }

 function getUsdValue(address token, uint256 amount) public view returns(uint256){
 AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
 (,int256 price,,,) = priceFeed.staleCheckLatestRoundData();

 return((uint256(price)*ADDITIONAL_FEED_PRECISION*amount)/PRECISION);

 }


 function _calculateHealthFactor(
   uint256 totalDscMinted,
   uint256 collateralValueInUsd
 ) internal pure returns(uint256)
 {
  if(totalDscMinted == 0) return type(uint256).max;
  uint256 collateralAdjustedForThreshold = (collateralValueInUsd*LIQUIDATION_THRESHOLD)/ LIQUIDATION_PRECISION;
  return(collateralAdjustedForThreshold*PRECISION)/ totalDscMinted;

 }

 function calculateHealthFactor(
   uint256 totalDscMinted,
   uint256 collateralValueInUsd
 ) external 
 pure
 returns(uint256)
 {
   return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);

 }

 

 function getTokenAmountFromUsd(address token,uint256 usdAmountInWei)public view returns(uint256){
    AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
    ( , int256 price, , ,) = priceFeed.staleCheckLatestRoundData();

    return (usdAmountInWei*PRECISION)/(uint256(price)*ADDITIONAL_FEED_PRECISION);
 }
 
 //private internal view function

 function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral,address from,address to) private{

 s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;

 emit collateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
  bool success = IERC20(tokenCollateralAddress).transfer(to,amountCollateral);
 if(!success){
    revert DSCEngine_TransferFailed();
  }


 }


 function _burnDsc(uint256 amountDscToBurn, address onBehalfOf,address dscFrom) private{
 s_DSCMinted[onBehalfOf] -=amountDscToBurn;

 bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
 if(!success){
    revert  DSCEngine_TransferFailed();

 }
 i_dsc.burn(amountDscToBurn);

 }
function getPrecision() external pure returns (uint256) {
    return PRECISION;
}

function getAdditionalFeedPrecision() external pure returns (uint256) {
    return ADDITIONAL_FEED_PRECISION;
}

function getLiquidationThreshold() external pure returns (uint256) {
    return LIQUIDATION_THRESHOLD;
}

function getLiquidationBonus() external pure returns (uint256) {
    return LIQUIDATION_BONUS;
}

function getLiquidationPrecision() external pure returns (uint256) {
    return LIQUIDATION_PRECISION;
}

function getMinHealthFactor() external pure returns (uint256) {
    return MIN_HEALTH_FACTOR;
}

function getCollateralTokens() external view returns (address[] memory) {
    return s_collateralTokens;
}

function getDsc() external view returns (address) {
    return address(i_dsc);
}

function getCollateralTokenPriceFeed(address token) external view returns (address) {
    return s_priceFeeds[token];
}

 function getHealthFactor(address user) external view returns (uint256) {
    return _healthFactor(user);

}
function getCollateralBalanceOfUser(address user, address token) external view returns(uint256) {
    return s_collateralDeposited[user][token];
 }

 function getAccountInformation(address user) external view returns (uint256 totalDscMinted, uint256 collateralValueInUsd) {
    return _getAccountInformation(user);
}


}




