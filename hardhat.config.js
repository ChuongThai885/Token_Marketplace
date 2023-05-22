require("@nomicfoundation/hardhat-toolbox")
require("@nomiclabs/hardhat-etherscan")
require("hardhat-deploy")
require("solidity-coverage")
require("hardhat-gas-reporter")
require("hardhat-contract-sizer")
require("dotenv").config()

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

const SEPOLIA_RPC_URL =
    process.env.SEPOLIA_RPC_URL || "https://eth-sepolia.g.alchemy.com/v2/YOUR-API-KEY"
const PRIVNET_RPC_URL = process.env.PRIVNET_RPC_URL || "http://localhost:8545"
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0xKey"
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "key"
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "key"

module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            chainId: 31337,
        },
        localhost: {
            chainId: 31337,
        },
        sepolia: {
            url: SEPOLIA_RPC_URL,
            accounts: [PRIVATE_KEY],
            saveDeployments: true,
            chainId: 11155111,
            blockConfirmation: 6,
        },
        privnet: {
            url: PRIVNET_RPC_URL,
            accounts: [PRIVATE_KEY],
            saveDeployments: true,
            chainId: 6969,
            blockConfirmation: 2,
        },
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY,
    },
    gasReporter: {
        enabled: true,
        outputFile: "gas-report.txt",
        noColors: true,
        currency: "USD",
        coinmarketcap: COINMARKETCAP_API_KEY,
        token: "ETH",
    },
    contractSizer: {
        runOnCompile: false,
        only: ["TokenMarketplace"],
    },
    namedAccounts: {
        deployer: {
            default: 0,
            1: 0,
        },
        user1: {
            default: 1,
        },
        user2: {
            default: 2,
        },
    },
    solidity: {
        compilers: [{ version: "0.8.18" }, { version: "0.4.24" }],
    },
    mocha: {
        timeout: 200000, // 200 seconds max for running tests
    },
}
