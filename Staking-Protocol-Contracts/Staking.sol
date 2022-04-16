// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./XYZToken.sol";
import "./ABCToken.sol";

contract Staking {
    XYZToken public stakingToken;
    ABCToken public rewardToken;

    struct Stake {
        address user;
        uint256 amount;
        uint256 since;
        uint256 claimable;
    }

    struct Stakeholder {
        address user;
        Stake[] address_stakes;
    }

    Stakeholder internal stakeholder;
    Stakeholder[] internal stakeholders;

    mapping(address => uint256) internal stakes;

    uint256 public totalStaking;

    struct StakingSummary {
        uint256 total_amount;
        Stake[] stakes;
    }

    event Staked(
        address indexed user,
        uint256 amount,
        uint256 index,
        uint256 timestamp
    );

    constructor(ABCToken _rewardToken, XYZToken _stakingToken) public {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        stakeholders.push(stakeholder);
    }

    function _addStakeholder(address staker) internal returns (uint256) {
        // Push a empty item to the Array to make space for our new stakeholder
        stakeholders.push(stakeholder);
        // Calculate the index of the last item in the array by Len-1
        uint256 userIndex = stakeholders.length - 1;
        // Assign the address to the new index
        stakeholders[userIndex].user = staker;
        // Add index to the stakeHolders
        stakes[staker] = userIndex;
        return userIndex;
    }

    function stake(uint256 _amount) public {
        // Simple check so that user does not stake 0
        require(_amount > 0, "Cannot stake nothing");
        require(
            _amount < stakingToken.balanceOf(msg.sender),
            "Cannot stake more than you own"
        );

        // Mappings in solidity creates all values, but empty, so we can just check the address
        uint256 index = stakes[msg.sender];
        // block.timestamp = timestamp of the current block in seconds since the epoch
        uint256 timestamp = block.timestamp;
        // See if the staker already has a staked index or if its the first time
        if (index == 0) {
            // This stakeholder stakes for the first time
            // We need to add him to the stakeHolders and also map it into the Index of the stakes
            // The index returned will be the index of the stakeholder in the stakeholders array
            index = _addStakeholder(msg.sender);
        }

        // Use the index to push a new Stake
        // push a newly created Stake with the current block timestamp.
        stakeholders[index].address_stakes.push(
            Stake(msg.sender, _amount, timestamp, 0)
        );
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        totalStaking += _amount;
        // Emit an event that the stake has occured
        emit Staked(msg.sender, _amount, index, timestamp);
    }

    function calculateStakeReward(Stake memory _current_stake)
        internal
        view
        returns (uint256)
    {
        return (((block.timestamp - _current_stake.since) / 1 days) *
            ((_current_stake.amount * 10000) / (totalStaking * 365)));
    }

    function withdrawStake(uint256 amount, uint256 index)
        public
        returns (uint256, uint256)
    {
        // Grab user_index which is the index to use to grab the Stake[]
        uint256 user_index = stakes[msg.sender];
        Stake memory current_stake = stakeholders[user_index].address_stakes[
            index
        ];
        require(
            current_stake.amount >= amount,
            "Staking: Cannot withdraw more than you have staked"
        );

        // Calculate available Reward first before we start modifying data
        uint256 reward = calculateStakeReward(current_stake);
        // Remove by subtracting the money unstaked
        current_stake.amount = current_stake.amount - amount;
        // If stake is empty, 0, then remove it from the array of stakes
        if (current_stake.amount == 0) {
            delete stakeholders[user_index].address_stakes[index];
        } else {
            // If not empty then replace the value of it
            stakeholders[user_index]
                .address_stakes[index]
                .amount = current_stake.amount;
            // Reset timer of stake
            stakeholders[user_index].address_stakes[index].since = block
                .timestamp;
        }

        stakingToken.transfer(msg.sender, amount);
        rewardToken.mint(msg.sender, reward);
        totalStaking -= amount;

        return (amount, reward);
    }

    function stakingSummary(address _staker)
        public
        view
        returns (StakingSummary memory)
    {
        // totalStakeAmount is used to count total staked amount of the address
        uint256 totalStakeAmount;
        // Keep a summary in memory since we need to calculate this
        StakingSummary memory summary = StakingSummary(
            0,
            stakeholders[stakes[_staker]].address_stakes
        );
        // Itterate all stakes and grab amount of stakes
        for (uint256 s = 0; s < summary.stakes.length; s += 1) {
            uint256 availableReward = calculateStakeReward(summary.stakes[s]);
            summary.stakes[s].claimable = availableReward;
            totalStakeAmount = totalStakeAmount + summary.stakes[s].amount;
        }
        // Assign calculate amount to summary
        summary.total_amount = totalStakeAmount;
        return summary;
    }

    function claimRewards() public returns (bool) {
        uint256 user_index = stakes[msg.sender];
        uint256 reward;
        for (
            uint256 s = 0;
            s < stakeholders[user_index].address_stakes.length;
            s += 1
        ) {
            uint256 availableReward = calculateStakeReward(
                stakeholders[user_index].address_stakes[s]
            );
            reward += availableReward;
            // Reset timer of stake
            stakeholders[user_index].address_stakes[s].since = block.timestamp;
        }
        if (reward > 0) {
            rewardToken.mint(msg.sender, reward);
        }
        return true;
    }
}
