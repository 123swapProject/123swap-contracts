 module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer, dev } = await getNamedAccounts()

  await deploy("OneTwoThreeBonusToken", {
    from: dev,
    log: true,
    deterministicDeployment: false
  })
}

module.exports.tags = ["OneTwoThreeBonusToken"]
module.exports.dependencies = ["UniswapV2Factory", "UniswapV2Router02"]
