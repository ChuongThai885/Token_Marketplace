const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()
    await deploy("TokenMarketplace", {
        from: deployer,
        args: [],
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
    if (
        !developmentChains.includes(network.name) &&
        network.name !== "privnet" &&
        process.env.ETHERSCAN_API_KEY
    ) {
        await verify(customToken.address, [INITIAL_SUPPLY])
    }
}

module.exports.tags = ["all", "TokenMarketplace"]
