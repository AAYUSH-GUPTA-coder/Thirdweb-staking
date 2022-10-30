// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ERC721Staking is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Interface for ERC20 and ERC721
    IERC20 public immutable rewardToken;
    IERC20 public immutable nftCollection;

    // Contructor function to set the rewards token and the nft collection addresses
    constructor(IERC721 _nftCollection, IERC20 _rewardToken){
        nftCollection = _nftCollection;
        rewardToken = _rewardToken;
    }

    struct StakeToken {
        address staker;
        address tokenId;
    }

    // staker info
    struct Staker {
        // Amount of tokens staked by the staker
        uint256 amountStaked;

        // Staked token ids
        StakedToken[] stakedTokens;

        // Last time of the rewards were calculated for this user
        uint256 timeOfLastUpdate;

        // Calculated, unclaimed rewards for the User. The rewards are
        // calculated each time the user writes to the Smart Contract
        uint256 unclaimedRewards;
    }

    // Rewards per hour per token deposited in wei.
    uint256 private rewardsPerHour = 100000;

    // Mapping of User Address to Staker info
    mapping(address => Staker) public stakers;

    // Mapping of Token Id to staker. Made for the SC to remeber
    // who to send back the ERC721 Token to.
    mapping(uint256 => address) public stakerAddress;

    // If address already has ERC721 Token/s staked, calculate the rewards.
    // Increment the amountStaked and map msg.sender to the Token Id of the staked
    // Token to later send back on withdrawal. Finally give timeOfLastUpdate the
    // value of now.
    function stake(uint256 _tokenId) external nonReentrant {
        // If wallet has tokens staked, calculate the rewards before adding the new token
        if (stakers[msg.sender].amountStaked > 0) {
            uint256 rewards = calculateRewards(msg.sender);
            stakers[msg.sender].unclaimedRewards += rewards;
        }

        // Wallet must own the token they are trying to stake
        require(
            nftCollection.ownerOf(_tokenId) == msg.sender,
            "You don't own this token!"
        );

        // Transfer the token from the wallet to the Smart contract
        nftCollection.transferFrom(msg.sender, address(this), _tokenId);

        // Create StakedToken
        StakedToken memory stakedToken = StakedToken(msg.sender, _tokenId);

        // Add the token to the stakedTokens array
        stakers[msg.sender].stakedTokens.push(stakedToken);

        // Increment the amount staked for this wallet
        stakers[msg.sender].amountStaked++;

        // Update the mapping of the tokenId to the staker's address
        stakerAddress[_tokenId] = msg.sender;

        // Update the timeOfLastUpdate for the staker   
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
    }
}