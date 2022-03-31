module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const { deploy, execute } = deployments

  const { deployer, dev } = await getNamedAccounts()

  const bonus = await ethers.getContract("OneTwoThreeBonusToken")
  const masterChef = await ethers.getContract("OneTwoThreeMasterChef")
  
  const { address } = await deploy("OneTwoThreeMasterChefV2", {
    from: dev,
    args: [masterChef, bonus.address, 0],
    log: true,
    deterministicDeployment: false
  })

  if (await bonus.owner() !== address) {
    console.log("Transfer Bonus Ownership to Chef")
    await execute(
      'OneTwoThreeBonusToken',
      {from: dev, log: true},
      'transferOwnership',
      address
    );
  }

  const OneTwoThreeMasterChefV2 = await ethers.getContract("OneTwoThreeMasterChefV2")
  if (await OneTwoThreeMasterChefV2.owner() !== dev) {
    console.log("Transfer ownership of OneTwoThreeMasterChefV2 to dev")
    await execute(
      'OneTwoThreeMasterChef',
      {from: dev, log: true},
      'transferOwnership',
      dev
    );
  }
}

module.exports.tags = ["OneTwoThreeMasterChef"]
module.exports.dependencies = ["UniswapV2Factory", "UniswapV2Router02", "OneTwoThreeBonusToken"]
