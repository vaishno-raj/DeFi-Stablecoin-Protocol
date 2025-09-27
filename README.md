# 🪙 DeFi Stablecoin Protocol

![GitHub license](https://img.shields.io/badge/License-MIT-blue.svg)
![Made with Foundry](https://img.shields.io/badge/Made%20with-Foundry-ff69b4)
![GitHub last commit](https://img.shields.io/github/last-commit/vaishno-raj/DeFi-Stablecoin-Protocol)
![GitHub issues](https://img.shields.io/github/issues/vaishno-raj/DeFi-Stablecoin-Protocol)

A decentralized stablecoin protocol built with **Solidity** and **Foundry**, inspired by MakerDAO-style collateralized debt positions (CDPs).  

This protocol allows users to:

- 🏦 **Deposit collateral** (ETH or other supported assets)  
- 💵 **Mint Decentralized Stablecoin (DSC)** against collateral  
- 🔄 **Redeem collateral** by burning DSC  
- ⚡ **Liquidate undercollateralized positions**  
- ✅ Fully tested with **unit tests**, **fuzzing**, and **invariant tests**  

---

## 📂 Project Structure

├── src/ # Core smart contracts
│ ├── DSCEngine.sol
│ ├── DecentralizedStableCoin.sol
│ └── libraries/OracleLib.sol
│
├── script/ # Deployment & helper scripts
│ ├── DeployDSC.s.sol
│ └── HelperConfig.s.sol
│
├── test/ # Test suite
│ ├── unit/ # Unit tests
│ ├── fuzz/ # Fuzzing & invariant tests
│ └── mock/ # Mocks (ERC20, price feeds)
│
├── foundry.toml # Foundry configuration
├── README.md # Project documentation
└── LICENSE # MIT License
  


---

## ⚡ Requirements
- [Foundry](https://book.getfoundry.sh/getting-started/installation)  
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup


## Getting started
git clone https://github.com/vaishno-raj/DeFi-Stablecoin-Protocol.git
cd DeFi-Stablecoin-Protocol

## Build

forge build

## Run Test

forge test

## Run a specific test by name

forge test -m "testDepositCollateral"

## Run test with verbose output

forge test -vvvv

## Fuzz & invariant testing

forge test --mt invariant_protocolMustHaveMoreValueThanTotalSupply -vvvv

