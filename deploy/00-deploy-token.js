const { network } = require("hardhat")
const {
    developmentChains,
    INITIAL_SUPPLY,
    TOKEN_NAME,
    TOKEN_SYMBOL,
} = require("../helper-hardhat-config")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments
    const { deployer, user1 } = await getNamedAccounts()

    if (developmentChains.includes(network.name)) {
        await deploy("CustomToken", {
            from: deployer,
            args: [TOKEN_NAME, TOKEN_SYMBOL, INITIAL_SUPPLY],
            log: true,

            waitConfirmations: network.config.blockConfirmations || 1,
        })
    }
}

module.exports.tags = ["all", "CustomToken"]
