const { assert, expect } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")
!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Token Marketplace Unit Test", () => {
          let marketplace, customToken, deployer, user1, user2
          const tokenAmount = ethers.utils.parseEther("5") // represent for 5 tokens
          const totalPrice = tokenAmount.mul(5) // 5 eth for 1 tokens
          beforeEach(async () => {
              const accounts = await getNamedAccounts()
              deployer = accounts.deployer
              user1 = accounts.user1
              user2 = accounts.user2

              await deployments.fixture("all")
              marketplace = await ethers.getContract("TokenMarketplace", deployer)
              customToken = await ethers.getContract("CustomToken", deployer)
          })
          it("was deployed", async () => {
              assert(customToken.address)
              assert(marketplace.address)
          })
          describe("Place Order", () => {
              it("Place sell order", async () => {
                  await customToken.approve(marketplace.address, tokenAmount)
                  await marketplace.placeSellOrder(customToken.address, tokenAmount, totalPrice)
                  const { amount, price } = await marketplace.getDetailSellOrder(
                      deployer,
                      customToken.address
                  )
                  assert.equal(totalPrice.toString(), price.mul(5).toString())
                  assert.equal(tokenAmount.toString(), amount.toString())
              })
              it("Not allow place sell order with the same token", async () => {
                  await customToken.approve(marketplace.address, tokenAmount.mul(2))
                  await marketplace.placeSellOrder(customToken.address, tokenAmount, totalPrice)
                  await expect(
                      marketplace.placeSellOrder(customToken.address, tokenAmount, totalPrice)
                  ).to.be.revertedWithCustomError(marketplace, "TokenMarketplace__SellOrderExisted")
              })
              it("Place buy order", async () => {
                  await marketplace.placeBuyOrder(customToken.address, tokenAmount, {
                      value: totalPrice,
                  })
                  const { amount, price } = await marketplace.getDetailBuyOrder(
                      deployer,
                      customToken.address
                  )
                  assert.equal(totalPrice.toString(), price.mul(5).toString())
                  assert.equal(tokenAmount.toString(), amount.toString())
              })
              it("Not allow place sell order with the same token", async () => {
                  await marketplace.placeBuyOrder(customToken.address, tokenAmount, {
                      value: totalPrice,
                  })
                  await expect(
                      marketplace.placeBuyOrder(customToken.address, tokenAmount, {
                          value: totalPrice,
                      })
                  ).to.be.revertedWithCustomError(marketplace, "TokenMarketplace__BuyOrderExisted")
              })
              it("Emits an OrderPlaced event when order being placed", async () => {
                  await customToken.approve(marketplace.address, tokenAmount.mul(2))
                  await expect(
                      marketplace.placeSellOrder(customToken.address, tokenAmount, totalPrice)
                  ).to.emit(marketplace, "OrderPlaced")
                  await expect(
                      marketplace.placeBuyOrder(customToken.address, tokenAmount, {
                          value: totalPrice,
                      })
                  ).to.emit(marketplace, "OrderPlaced")
              })
          })
          describe("Order matched", () => {
              let user1Marketplace, user2Marketplace
              beforeEach(async () => {
                  user1Marketplace = await ethers.getContract("TokenMarketplace", user1)
                  await user1Marketplace.placeBuyOrder(customToken.address, tokenAmount, {
                      value: totalPrice,
                  })
                  user2Marketplace = await ethers.getContract("TokenMarketplace", user2)
              })

              it("Order matched with same amount, remove buy and sell order", async () => {
                  const newTotalPrice = totalPrice.add(ethers.utils.parseEther("5"))
                  await customToken.approve(marketplace.address, tokenAmount)
                  await marketplace.placeSellOrder(customToken.address, tokenAmount, newTotalPrice)
                  await user2Marketplace.placeBuyOrder(customToken.address, tokenAmount, {
                      value: newTotalPrice,
                  })
                  assert.equal(
                      await marketplace.isOnOrderBook(deployer, customToken.address, false),
                      false
                  )
                  assert.equal(
                      await marketplace.isOnOrderBook(user2, customToken.address, true),
                      false
                  )
              })
              it("Order matched with same amount, send tokens to buyer and send money to seller", async () => {
                  await customToken.approve(marketplace.address, tokenAmount)
                  const startingAmount = await customToken.balanceOf(user1)
                  const startingBalance = await marketplace.provider.getBalance(deployer)
                  const transactionResponse = await marketplace.placeSellOrder(
                      customToken.address,
                      tokenAmount,
                      totalPrice
                  )
                  const endingAmount = await customToken.balanceOf(user1)
                  const endingBalance = await user1Marketplace.provider.getBalance(deployer)
                  const transactionReceipt = await transactionResponse.wait(1)
                  const { gasUsed, effectiveGasPrice } = transactionReceipt
                  const gasCost = gasUsed.mul(effectiveGasPrice)
                  assert.equal(startingAmount.add(tokenAmount).toString(), endingAmount.toString())
                  assert.equal(
                      startingBalance.add(totalPrice).toString(),
                      endingBalance.add(gasCost).toString()
                  )
              })
              it("Order matched with different amount, remove order with amount equal 0, send tokens to buyer and send money to seller", async () => {
                  const addingAmount = ethers.utils.parseEther("2")
                  const newTokenAmount = tokenAmount.add(addingAmount)
                  await user2Marketplace.placeBuyOrder(customToken.address, tokenAmount, {
                      value: totalPrice,
                  })
                  await customToken.approve(marketplace.address, newTokenAmount)
                  await marketplace.placeSellOrder(
                      customToken.address,
                      newTokenAmount,
                      totalPrice.add(addingAmount.mul("5"))
                  )
                  assert.equal(
                      await marketplace.isOnOrderBook(deployer, customToken.address, false),
                      false
                  )
                  assert.equal(
                      await marketplace.isOnOrderBook(user1, customToken.address, true),
                      false
                  )
                  const { amount } = await marketplace.getDetailBuyOrder(user2, customToken.address)
                  assert.equal(amount.add(addingAmount).toString(), tokenAmount.toString())
              })
              it("Emits an OrderMatched event when orders matched", async () => {
                  await customToken.approve(marketplace.address, tokenAmount)
                  await expect(
                      marketplace.placeSellOrder(customToken.address, tokenAmount, totalPrice)
                  ).to.emit(marketplace, "OrderMatched")
              })
          })
          describe("Cancel order", () => {
              let userMarketplace, userTotalPrice
              beforeEach(async () => {
                  await customToken.approve(marketplace.address, tokenAmount)
                  await marketplace.placeSellOrder(customToken.address, tokenAmount, totalPrice)

                  userMarketplace = await ethers.getContract("TokenMarketplace", user1)
                  userTotalPrice = totalPrice.add(ethers.utils.parseEther("5"))
                  await userMarketplace.placeBuyOrder(customToken.address, tokenAmount, {
                      value: userTotalPrice,
                  })
              })

              it("Revert when cancel order not own by sender", async () => {
                  await expect(
                      marketplace.cancelOrder(user1, customToken.address, true)
                  ).to.be.revertedWithCustomError(marketplace, "TokenMarketplace__NotOwner")
              })
              it("Revert when cancel non-existing order", async () => {
                  await expect(
                      marketplace.cancelOrder(deployer, customToken.address, true)
                  ).to.be.revertedWithCustomError(marketplace, "TokenMarketplace__BuyOrderNotExist")
                  await expect(
                      userMarketplace.cancelOrder(user1, customToken.address, false)
                  ).to.be.revertedWithCustomError(
                      userMarketplace,
                      "TokenMarketplace__SellOrderNotExist"
                  )
              })
              it("Cancel sell order", async () => {
                  await marketplace.cancelOrder(deployer, customToken.address, false)
                  assert.equal(
                      await marketplace.isOnOrderBook(deployer, customToken.address, false),
                      false
                  )
              })
              it("Send back token to owner when sell order being canceled", async () => {
                  const startingTokenBalance = await customToken.balanceOf(deployer)
                  await marketplace.cancelOrder(deployer, customToken.address, false)
                  const endingTokenBalance = await customToken.balanceOf(deployer)
                  assert.equal(
                      startingTokenBalance.add(tokenAmount).toString(),
                      endingTokenBalance.toString()
                  )
              })
              it("Cancel buy order", async () => {
                  await userMarketplace.cancelOrder(user1, customToken.address, true)
                  assert.equal(
                      await marketplace.isOnOrderBook(deployer, customToken.address, true),
                      false
                  )
              })
              it("Send back money to owner when buy order being canceled", async () => {
                  const startingUserBalance = await userMarketplace.provider.getBalance(user1)
                  const transactionResponse = await userMarketplace.cancelOrder(
                      user1,
                      customToken.address,
                      true
                  )
                  const transactionReceipt = await transactionResponse.wait(1)
                  const { gasUsed, effectiveGasPrice } = transactionReceipt
                  const gasCost = gasUsed.mul(effectiveGasPrice)
                  const endingUserBalance = await userMarketplace.provider.getBalance(user1)
                  assert.equal(
                      startingUserBalance.add(userTotalPrice).toString(),
                      endingUserBalance.add(gasCost).toString()
                  )
              })
              it("Emits an OrderCanceled event when order being canceled", async () => {
                  await expect(
                      marketplace.cancelOrder(deployer, customToken.address, false)
                  ).to.emit(marketplace, "OrderCanceled")
                  await expect(
                      userMarketplace.cancelOrder(user1, customToken.address, true)
                  ).to.emit(userMarketplace, "OrderCanceled")
              })
          })
      })
