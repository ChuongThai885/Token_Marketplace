const { getNamedAccounts, ethers } = require("hardhat")

async function main() {
    const { deployer } = await getNamedAccounts()
    marketplace = await ethers.getContract("TokenMarketplace", deployer)
    customToken = await ethers.getContract("CustomToken", deployer)
    const tokenAmount = ethers.utils.parseEther("5")
    const totalPrice = tokenAmount.mul(5)

    await customToken.approve(marketplace.address, tokenAmount)
    const transactionResponse = await marketplace.placeSellOrder(
        customToken.address,
        tokenAmount,
        totalPrice
    )
    await transactionResponse.wait(1)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
