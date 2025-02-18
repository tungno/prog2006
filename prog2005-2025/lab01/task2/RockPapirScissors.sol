// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
    Rock Paper Scissors Game

    Game rules:
      - Paper (P) beats Rock (R)
      - Rock (R) beats Scissors (S)
      - Scissors (S) beats Paper (P)
      
    Protocol overview:
      1. Both players “commit” to a move by sending a hash of their chosen move (one of "R", "P", or "S")
         combined with a secret salt. This is done in the `play` function.
      2. Both players must later “reveal” their move and salt via the `reveal` function.
      3. When both moves are revealed, the contract compares the moves, determines the winner and records
         which address is entitled to withdraw the entire pot. In the case of a tie each player is refunded.
      4. If one player (typically the “second” player) fails to reveal within a specified timeout period,
         the player who did reveal is allowed to withdraw the full stake (i.e. both players’ bets).
      
    Stake requirements:
      - The stake (msg.value) must be nonzero.
      - The second player must send exactly the same amount as the first.
      
    Additional requirements:
      - Only two players are allowed per game.
      - The same player may not play with himself.
      - Events are emitted when players play, reveal, and withdraw funds.
      - All moves (and all method calls) are public so that the “commit-reveal” scheme is necessary.
      - The contract uses a standard hash (keccak256) to verify a move with its salt.
*/

contract RockPaperScissors {
    // --- EVENTS ---
    event Played(address indexed player, bytes32 hashedVote);
    event Revealed(address indexed player, string vote);
    event Withdrawn(address indexed player, uint256 amount);

    // --- CONSTANTS ---
    // Timeout period for the reveal phase.
    uint256 public constant revealTimeout = 5 minutes;

    // --- GAME STATE VARIABLES ---
    address public player1;
    address public player2;
    uint256 public bet;            // The stake amount (both players must wager the same amount)
    bytes32 public commit1;        // Hashed move (commitment) of player1
    bytes32 public commit2;        // Hashed move (commitment) of player2
    bool public revealed1;         // Whether player1 has revealed their move
    bool public revealed2;         // Whether player2 has revealed their move
    string public move1;           // Player1's revealed move ("R", "P", or "S")
    string public move2;           // Player2's revealed move ("R", "P", or "S")
    uint256 public gameStartTime;  // Timestamp when player2 joined (to enforce the reveal timeout)
    bool public gameCompleted;     // Flag that the game has been finalized (by proper reveal or timeout)
    address public winner;         // Address of the winner (if any)
    bool public tie;               // Flag indicating that the game ended in a tie

    // --- PENDING WITHDRAWALS ---
    // Instead of sending funds immediately, I use a withdrawal pattern.
    mapping(address => uint256) public pendingWithdrawals;

    // --- FUNCTION: play ---
    /*
       The `play` function allows a player to enter the game by providing a hash of their move.
       The hash must be computed off-chain using:
          keccak256(abi.encodePacked(vote, salt))
       where vote is "R", "P", or "S", and salt is a secret.
       
       When the first player calls play, their address, commitment, and stake are recorded.
       When a second (different) player calls play with the same stake, their information is recorded,
       and the game’s reveal timeout timer starts.
    */
    function play(bytes32 _commitment) external payable {
        require(msg.value > 0, "Stake must be non-zero");
        
        // If no player1 yet, set msg.sender as player1.
        if (player1 == address(0)) {
            player1 = msg.sender;
            commit1 = _commitment;
            bet = msg.value;
            emit Played(msg.sender, _commitment);
        } 
        // Otherwise, if player1 exists but player2 is not set, then msg.sender becomes player2.
        else {
            require(player2 == address(0), "Game already has two players");
            require(msg.sender != player1, "Cannot play against yourself"); 
            require(msg.value == bet, "Stake must match player1's stake");
            
            player2 = msg.sender;
            commit2 = _commitment;
            // Set the time when player2 joined, to later enforce the reveal timeout.
            gameStartTime = block.timestamp;
            emit Played(msg.sender, _commitment);
        }
    }
    
    // --- FUNCTION: reveal ---
    /*
       The `reveal` function allows a player to reveal their move.
       The player must supply the plain-text move (which must be a single character "R", "P", or "S")
       and the salt that was used to create the hash.
       
       The contract recomputes the hash and checks it against the stored commitment.
       An event is emitted showing the player’s address and the revealed move.
       
       When both players have revealed, the game result is determined.
    */
    function reveal(string calldata _move, string calldata _salt) external {
        // Only a participant (player1 or player2) may call reveal.
        require(msg.sender == player1 || msg.sender == player2, "Not a participant");
        
        // Validate that _move is a single character ("R", "P", or "S").
        bytes memory moveBytes = bytes(_move);
        require(moveBytes.length == 1, "Move must be a single character");
        bytes1 moveChar = moveBytes[0];
        require(
            moveChar == bytes1("R") ||
            moveChar == bytes1("P") ||
            moveChar == bytes1("S"),
            "Invalid move. Use 'R', 'P', or 'S'"
        );
        
        // Compute the hash from the provided move and salt.
        bytes32 computedHash = keccak256(abi.encodePacked(_move, _salt));
        
        // Process reveal for player1.
        if (msg.sender == player1) {
            require(!revealed1, "Player1 already revealed");
            require(computedHash == commit1, "Invalid reveal for player1");
            revealed1 = true;
            move1 = _move;
            emit Revealed(msg.sender, _move);
        }
        // Process reveal for player2.
        else {
            require(!revealed2, "Player2 already revealed");
            require(computedHash == commit2, "Invalid reveal for player2");
            revealed2 = true;
            move2 = _move;
            emit Revealed(msg.sender, _move);
        }
        
        // If both players have revealed, determine the game outcome.
        if (revealed1 && revealed2) {
            _determineWinner();
        }
    }
    
    // --- INTERNAL FUNCTION: _determineWinner ---
    /*
       Once both moves are revealed, this function compares them according to the rules:
          - If both moves are identical, the game is a tie and each player may withdraw their own stake.
          - Otherwise, the winning move is determined and the winner is allocated the entire pot.
    */
    function _determineWinner() internal {
        // Convert the moves to bytes for easy comparison.
        bytes memory m1 = bytes(move1);
        bytes memory m2 = bytes(move2);
        
        // Check for tie.
        if(m1[0] == m2[0]) {
            tie = true;
            gameCompleted = true;
            // In case of a tie, each player is allowed to withdraw their own bet.
            pendingWithdrawals[player1] = bet;
            pendingWithdrawals[player2] = bet;
        } else {
            // Determine the winner by comparing moves:
            //   - "R" beats "S"
            //   - "P" beats "R"
            //   - "S" beats "P"
            if (
                (m1[0] == bytes1("R") && m2[0] == bytes1("S")) ||
                (m1[0] == bytes1("P") && m2[0] == bytes1("R")) ||
                (m1[0] == bytes1("S") && m2[0] == bytes1("P"))
            ) {
                winner = player1;
            } else {
                winner = player2;
            }
            gameCompleted = true;
            // The winner receives both players’ stakes.
            pendingWithdrawals[winner] = bet * 2;
        }
    }
    
    // --- FUNCTION: withdraw ---
    /*
       The `withdraw` function lets the winning party (or in case of a tie, each player for their own stake)
       claim their funds.
       
       It also covers the situation where the game does not conclude normally because one player fails to reveal.
       In that case, once the reveal timeout (set by `revealTimeout`) has passed, if exactly one player has revealed,
       that player is deemed the winner and may withdraw the full pot.
       
       After funds are withdrawn (and if applicable both parties have withdrawn in a tie), the game state is reset
       so that a new round may begin.
    */
    function withdraw() external {
        // If the game is not finalized, check whether the reveal timeout has been reached.
        if (!gameCompleted && player2 != address(0)) {
            // Ensure that the reveal timeout period has passed.
            if (block.timestamp >= gameStartTime + revealTimeout) {
                // If only one player has revealed, that player wins by timeout.
                if (revealed1 && !revealed2) {
                    winner = player1;
                    gameCompleted = true;
                    pendingWithdrawals[player1] = bet * 2;
                } else if (revealed2 && !revealed1) {
                    // (This branch is added for fairness even though the requirements mention player1.)
                    winner = player2;
                    gameCompleted = true;
                    pendingWithdrawals[player2] = bet * 2;
                } else {
                    revert("No reveal made by any player; cannot withdraw");
                }
            } else {
                revert("Game not completed and reveal timeout not reached");
            }
        }
        
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds available for withdrawal");
        
        // Reset the pending amount before transferring to prevent re-entrancy.
        pendingWithdrawals[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal transfer failed");
        emit Withdrawn(msg.sender, amount);
        
        // If the game is complete and (in a tie) both players have withdrawn, reset the game state.
        if(gameCompleted) {
            if(pendingWithdrawals[player1] == 0 && pendingWithdrawals[player2] == 0) {
                _resetGame();
            }
        }
    }
    
    // --- INTERNAL FUNCTION: _resetGame ---
    /*
       After a game is finished (withdrawals completed), this function resets all game state variables,
       allowing a new game to be started.
    */
    function _resetGame() internal {
        player1 = address(0);
        player2 = address(0);
        bet = 0;
        commit1 = 0;
        commit2 = 0;
        revealed1 = false;
        revealed2 = false;
        move1 = "";
        move2 = "";
        gameStartTime = 0;
        gameCompleted = false;
        winner = address(0);
        tie = false;
    }
    
    // Fallback function to receive funds (if necessary).
    receive() external payable {}
}


