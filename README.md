# Token_Marketplace

## Descriptions

This project is a Token Marketplace contract responsible for the logic function of the marketplace like place buy/ sell order, cancel order... This contract also contains a simple version of Order Matching algorithm to handle orders when they are put into the contract.

The idea is to create a smart contract that acts as an intermediary for buying and selling ERC20 tokens between buyers and sellers, with the added functionality of locating suitable orders for matching purposes.

## Available Scripts

In the project directory, you can run:

### `yarn hardhat help`

A command used in the Hardhat development environment to display a list of available commands and their descriptions. This command is helpful for developers who are new to Hardhat or who need a quick reference to the available commands and their functions. The output of the yarn hardhat help command includes a list of common commands, such as compile, test, and deploy, as well as less commonly used commands, such as flattener and verify. Additionally, the yarn hardhat help command provides information on how to use each command and its available options and arguments.

### `yarn hardhat test`

A command used in the Hardhat development environment for running automated tests on smart contracts written in Solidity. This command executes all the test scripts located in the test directory of a Hardhat project and displays the results of each test. The yarn hardhat test command is commonly used by developers to ensure that their smart contracts are functioning as intended and to catch any potential bugs or errors before deploying the contracts to the blockchain network.

### `yarn hardhat node`

A command used to run a local Ethereum blockchain node using Hardhat. This node uses a local Ethereum test network managed by Hardhat, allowing you to deploy and test smart contracts on an Ethereum-like environment without connecting to a real blockchain network.

### `yarn hardhat run scripts/placeSellOrder.js --network localhost`

A command used to place a sell order for testing when local Ethereum blockchain node is running