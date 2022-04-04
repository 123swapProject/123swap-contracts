module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const { deploy, execute } = deployments

  const { deployer, dev } = await getNamedAccounts()

  const bonus = await ethers.getContract("OneTwoThreeBonusToken")
  const masterChef = await ethers.getContract("OneTwoThreeMasterChef")

  const { address } = await deploy("OneTwoThreeMasterChefV2", {
    from: dev,
    args: [masterChef.address, bonus.address, 0],
    log: true,
    deterministicDeployment: false
  })

  const OneTwoThreeMasterChefV2 = await ethers.getContract("OneTwoThreeMasterChefV2")
  if (await OneTwoThreeMasterChefV2.owner() !== dev) {
    console.log("Transfer ownership of OneTwoThreeMasterChefV2 to dev")
    await execute(
      'OneTwoThreeMasterChefV2',
      {from: dev, log: true},
      'transferOwnership',
      dev
    );
  }

  await deploy("SimpleERC20", {
    from: dev,
    args: ["MCDUMMY", "MCDUMMY", "1"],
    log: true,
    deterministicDeployment: false
  })

  const mcDummy = await ethers.getContract("SimpleERC20")
  let poolLength = await masterChef.poolLength();

  if (poolLength.eq(0)) {
    console.log("Adding dummy pool for MC2", mcDummy.address)
    await execute(
      'OneTwoThreeMasterChef',
      {from: dev, log: true},
      'add',
      1000, mcDummy.address, true
    );

    console.log("Initiating dummy pool for MC2")
    await execute(
      'SimpleERC20',
      {from: dev, log: true},
      'approve',
      address, 1
    );

    await execute(
      'OneTwoThreeMasterChefV2',
      {from: dev, log: true},
      'init',
      mcDummy.address
    );
  }
}



module.exports.tags = ["OneTwoThreeMasterChef"]
module.exports.dependencies = ["UniswapV2Factory", "UniswapV2Router02", "OneTwoThreeBonusToken"]
