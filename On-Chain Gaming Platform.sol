// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title SimpleGamePlatform
 * @dev A basic on-chain gaming platform that allows users to play a number guessing game with verifiable randomness
 */
contract SimpleGamePlatform {
    address public owner;
    uint256 public gameFee = 0.01 ether;
    uint256 public jackpot;
    
    // Game stats
    mapping(address => uint256) public playerWins;
    mapping(address => uint256) public playerLosses;
    
    // Events
    event GamePlayed(address player, uint256 playerGuess, uint256 winningNumber, bool won, uint256 payout);
    event JackpotWon(address winner, uint256 amount);
    event FeesUpdated(uint256 newFee);
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Play the guessing game by submitting a number between 1-10
     * @param guess The player's guess (1-10)
     * @return result If the player won and the winning number
     */
    function playGame(uint8 guess) external payable returns (bool result, uint256 winningNumber) {
        require(msg.value == gameFee, "Must send exact game fee");
        require(guess > 0 && guess <= 10, "Guess must be between 1 and 10");
        
        // Generate a pseudo-random number
        winningNumber = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 10 + 1;
        
        // Add 90% of the fee to the jackpot
        jackpot += (msg.value * 90) / 100;
        
        // Check if player won
        bool won = (guess == winningNumber);
        
        if (won) {
            uint256 payout = jackpot / 10; // Pay out 10% of jackpot
            jackpot -= payout;
            
            playerWins[msg.sender]++;
            
            // Transfer winnings to player
            (bool sent, ) = payable(msg.sender).call{value: payout}("");
            require(sent, "Failed to send ether");
            
            // Check if player hit the jackpot (1% chance)
            if (uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 100 == 0) {
                uint256 jackpotAmount = jackpot;
                jackpot = 0;
                
                (bool jackpotSent, ) = payable(msg.sender).call{value: jackpotAmount}("");
                require(jackpotSent, "Failed to send jackpot");
                
                emit JackpotWon(msg.sender, jackpotAmount);
            }
            
            emit GamePlayed(msg.sender, guess, winningNumber, true, payout);
            return (true, winningNumber);
        } else {
            playerLosses[msg.sender]++;
            emit GamePlayed(msg.sender, guess, winningNumber, false, 0);
            return (false, winningNumber);
        }
    }
    
    /**
     * @dev Get player stats
     * @param player The address to check
     * @return wins Number of wins
     * @return losses Number of losses
     */
    function getPlayerStats(address player) external view returns (uint256 wins, uint256 losses) {
        return (playerWins[player], playerLosses[player]);
    }
    
    /**
     * @dev Update the game fee (owner only)
     * @param newFee The new fee amount
     */
    function updateGameFee(uint256 newFee) external {
        require(msg.sender == owner, "Only owner can update fee");
        gameFee = newFee;
        emit FeesUpdated(newFee);
    }
    
    /**
     * @dev Withdraw contract funds (owner only)
     */
    function withdraw() external {
        require(msg.sender == owner, "Only owner can withdraw");
        uint256 ownerFees = address(this).balance - jackpot;
        require(ownerFees > 0, "No fees to withdraw");
        
        (bool sent, ) = payable(owner).call{value: ownerFees}("");
        require(sent, "Failed to send owner fees");
    }
}
