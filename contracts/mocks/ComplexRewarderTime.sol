// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "../interfaces/IRewarder.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "../OneTwoThreeMasterChefV2.sol";

/// @author @0xKeno
contract ComplexRewarderTime is IRewarder,  BoringOwnable{
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringERC20 for IERC20;

    IERC20 private immutable rewardToken;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of BONUS entitled to the user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 unpaidRewards;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of BONUS to distribute per block.
    struct PoolInfo {
        uint128 accBonusPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    /// @notice Info of each pool.
    mapping (uint256 => PoolInfo) public poolInfo;

    uint256[] public poolIds;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 totalAllocPoint;

    uint256 public rewardPerSecond;
    uint256 private constant ACC_TOKEN_PRECISION = 1e12;

    address private immutable MASTERCHEF_V2;

    uint256 internal unlocked;
    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    event LogOnReward(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint);
    event LogUpdatePool(uint256 indexed pid, uint64 lastRewardTime, uint256 lpSupply, uint256 accBonusPerShare);
    event LogRewardPerSecond(uint256 rewardPerSecond);
    event LogInit();

    constructor (IERC20 _rewardToken, uint256 _rewardPerSecond, address _MASTERCHEF_V2) public {
        rewardToken = _rewardToken;
        rewardPerSecond = _rewardPerSecond;
        MASTERCHEF_V2 = _MASTERCHEF_V2;
        unlocked = 1;
    }


    function onBonusReward (uint256 pid, address _user, address to, uint256, uint256 lpToken) onlyMCV2 lock override external {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][_user];
        uint256 pending;
        if (user.amount > 0) {
            pending =
                (user.amount.mul(pool.accBonusPerShare) / ACC_TOKEN_PRECISION).sub(
                    user.rewardDebt
                ).add(user.unpaidRewards);
            uint256 balance = rewardToken.balanceOf(address(this));
            if (pending > balance) {
                rewardToken.safeTransfer(to, balance);
                user.unpaidRewards = pending - balance;
            } else {
                rewardToken.safeTransfer(to, pending);
                user.unpaidRewards = 0;
            }
        }
        user.amount = lpToken;
        user.rewardDebt = lpToken.mul(pool.accBonusPerShare) / ACC_TOKEN_PRECISION;
        emit LogOnReward(_user, pid, pending - user.unpaidRewards, to);
    }

    function pendingTokens(uint256 pid, address user, uint256) override external view returns (IERC20[] memory rewardTokens, uint256[] memory rewardAmounts) {
        IERC20[] memory _rewardTokens = new IERC20[](1);
        _rewardTokens[0] = (rewardToken);
        uint256[] memory _rewardAmounts = new uint256[](1);
        _rewardAmounts[0] = pendingToken(pid, user);
        return (_rewardTokens, _rewardAmounts);
    }

    /// @notice Sets the bonus per second to be distributed. Can only be called by the owner.
    /// @param _rewardPerSecond The amount of bonus to be distributed per second.
    function setRewardPerSecond(uint256 _rewardPerSecond) public onlyOwner {
        rewardPerSecond = _rewardPerSecond;
        emit LogRewardPerSecond(_rewardPerSecond);
    }

    modifier onlyMCV2 {
        require(
            msg.sender == MASTERCHEF_V2,
            "Only MCV2 can call this function."
        );
        _;
    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolIds.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _pid Pid on MCV2
    function add(uint256 allocPoint, uint256 _pid) public onlyOwner {
        require(poolInfo[_pid].lastRewardTime == 0, "Pool already exists");
        uint256 lastRewardTime = block.timestamp;
        totalAllocPoint = totalAllocPoint.add(allocPoint);

        poolInfo[_pid] = PoolInfo({
            allocPoint: allocPoint.to64(),
            lastRewardTime: lastRewardTime.to64(),
            accBonusPerShare: 0
        });
        poolIds.push(_pid);
        emit LogPoolAddition(_pid, allocPoint);
    }

    /// @notice Update the given pool's BONUS allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint256 _pid, uint256 _allocPoint) public onlyOwner {
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint.to64();
        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice Allows owner to reclaim/withdraw any tokens (including reward tokens) held by this contract
    /// @param token Token to reclaim, use 0x00 for Ethereum
    /// @param amount Amount of tokens to reclaim
    /// @param to Receiver of the tokens, first of his name, rightful heir to the lost tokens,
    /// reightful owner of the extra tokens, and ether, protector of mistaken transfers, mother of token reclaimers,
    /// the Khaleesi of the Great Token Sea, the Unburnt, the Breaker of blockchains.
    function reclaimTokens(address token, uint256 amount, address payable to) public onlyOwner {
        if (token == address(0)) {
            to.transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /// @notice View function to see pending Token
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending BONUS reward for a given user.
    function pendingToken(uint256 _pid, address _user) public view returns (uint256 pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accBonusPerShare = pool.accBonusPerShare;
        uint256 lpSupply = OneTwoThreeMasterChefV2(MASTERCHEF_V2).lpToken(_pid).balanceOf(MASTERCHEF_V2);
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 time = block.timestamp.sub(pool.lastRewardTime);
            uint256 bonusReward = time.mul(rewardPerSecond).mul(pool.allocPoint) / totalAllocPoint;
            accBonusPerShare = accBonusPerShare.add(bonusReward.mul(ACC_TOKEN_PRECISION) / lpSupply);
        }
        pending = (user.amount.mul(accBonusPerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt).add(user.unpaidRewards);
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (block.timestamp > pool.lastRewardTime) {
            uint256 lpSupply = OneTwoThreeMasterChefV2(MASTERCHEF_V2).lpToken(pid).balanceOf(MASTERCHEF_V2);

            if (lpSupply > 0) {
                uint256 time = block.timestamp.sub(pool.lastRewardTime);
                uint256 bonusReward = time.mul(rewardPerSecond).mul(pool.allocPoint) / totalAllocPoint;
                pool.accBonusPerShare = pool.accBonusPerShare.add((bonusReward.mul(ACC_TOKEN_PRECISION) / lpSupply).to128());
            }
            pool.lastRewardTime = block.timestamp.to64();
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accBonusPerShare);
        }
    }

}