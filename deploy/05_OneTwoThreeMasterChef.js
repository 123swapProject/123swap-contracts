module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const { deploy, execute } = deployments

  const { deployer, dev } = await getNamedAccounts()

  const bonus = await ethers.getContract("OneTwoThreeBonusToken")
  
  const { address } = await deploy("OneTwoThreeMasterChef", {
    from: dev,
    args: [bonus.address, dev, "1000000000000000000", "0", "100000000000000000000000"],
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

  const OneTwoThreeMasterChef = await ethers.getContract("OneTwoThreeMasterChef")
  if (await OneTwoThreeMasterChef.owner() !== dev) {
    console.log("Transfer ownership of OneTwoThreeMasterChef to dev")
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
