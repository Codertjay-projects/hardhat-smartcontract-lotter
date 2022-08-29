// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import '@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol';


/*@notice error used for not enough eth mostly when you enter raffle*/
	error Raffle_NotEnoughETHEntered();
	error Raffle_TransferFailed();
	error Raffle_NotOpen();
	error Raffle__UpKeepNotNeeded(
		uint256 currentBalance,
		uint256 numPlayers,
		uint256 raffleState);

/** @title A Sample Raffle Contract
* @author Afenikhena favour
* @notice This Contract is for creating an untamperable decentralized smart contract
 * @dev This implement Chainlink VrfV2 Chainlink keepers
 */
contract Raffle is VRFConsumerBaseV2 {
	/* Type Declaration */
	enum RaffleState{
		OPEN,
		CALCULATING
	}
	
	/* state variables*/
	uint256 private immutable i_entranceFee;
	address payable[]  private s_players;
	VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
	bytes32 private immutable i_gasLane;
	uint64 private immutable i_subscriptionId;
	uint32 private immutable i_callbackGasLimit;
	uint16 private constant REQUEST_CONFIRMATIONS = 3;
	uint16 private constant NUM_WORDS = 1;
	
	//	Lottery Variables
	address  private s_recentWinner;
	RaffleState private s_raffleState;
	uint256 private s_lastTimeStamp;
	uint256 private immutable i_interval;
	
	
	
	/*Events */
	event RaffleEnter(address indexed player);
	event RequestedRaffleWinner(uint256 indexed requestId);
	event WinnerPicked(address indexed winner);
	
	/* added the constructor for vrf consumer base and passed in
	the address vrfCoordinator address
	*/
	constructor(address vrfCoordinatorV2,
		uint256 entranceFee,
		bytes32 gasLane,
		uint64 subscriptionId,
		uint32 callbackGasLimit,
		uint256 interval
	)
	VRFConsumerBaseV2(vrfCoordinatorV2){
		i_entranceFee = entranceFee;
		/* setting the vrf coordinator interface*/
		i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
		i_gasLane = gasLane;
		i_subscriptionId = subscriptionId;
		i_callbackGasLimit = callbackGasLimit;
		s_raffleState = RaffleState.OPEN;
		s_lastTimeStamp = block.timestamp;
		i_interval = interval;
	}
	/* Adder an address to the raffle */
	function enterRaffle() public payable {
		// require (msg.value > i_entranceFee, "Not enough eth!");
		if (msg.value < i_entranceFee) {
			revert Raffle_NotEnoughETHEntered();
		}
		if (s_raffleState != RaffleState.OPEN) {
			revert Raffle_NotOpen();
		}
		/* msg.sender is not payable so we have to type cast it */
		s_players.push(payable(msg.sender));
		// Emit an event when we update a dynamic array or mapping
		// Named events with the function name reversed
		emit RaffleEnter(msg.sender);
	}
	
	/*
	*@dev This is the function that the chainlink keeper call .
	*They look for the `upKeepNeeded` to return true.
	* The following should be true in order to return true.
	* 1. Our time interval should have at least 1 player, and have some ETH
	* 2 The lottery should have at least 1 player, and have some ETH
	* 3. Our subscription is funded with link
	* 4. The lottery should be in an open state
	* Its more of like checking this till it returns true then it performs the
	* performUpKeep function which we request for the random winner
	*/
	function checkUpKeep(bytes memory /*checkData*/) public view override
	returns (
		bool upKeepNeeded,
		bytes memory /*performData*/) {
		bool isOpen = (RaffleState.OPEN == s_raffleState);
		bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
		bool hasPlayers = (s_players.length > 0);
		bool hasBalance = address(this).balance > 0;
		upKeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
		//		return upKeepNeeded;
	}
	
	/* Pick a random winner
	* the performData is a bytes param that could be passed from the checkUpKeep
	*but right now it is not needed
	*/
	function performUpKeep(bytes calldata /*performData*/) external override {
		// Request the random number
		// once we get it , do something with it
		// 2 transactions process
		(bool upKeepNeeded,) = checkUpKeep("");
		
		if (!upKeepNeeded) {
			revert Raffle__UpKeepNotNeeded(
				address(this).balance, s_players.length, uint256(s_raffleState));
		}
		
		s_raffleState = RaffleState.CALCULATING;
		uint256 requestId = i_vrfCoordinator.requestRandomWords(
			i_gasLane,
			i_subscriptionId,
			REQUEST_CONFIRMATIONS,
			i_callbackGasLimit,
			NUM_WORDS
		);
		emit RequestedRaffleWinner(requestId);
		
	}
	
	
	function fulfillRandomWords(
		uint256 /*requestId*/,
		uint256[] memory randomWords) internal override {
		
		s_raffleState = RaffleState.OPEN;
		uint256 indexOfWinner = randomWords[0] % s_players.length;
		address payable recentWinner = s_players[indexOfWinner];
		s_recentWinner = recentWinner;
		s_players = new address payable[](0);
		s_lastTimeStamp = block.timestamp;
		/* send all money to the recentWinner*/
		(bool success,) = recentWinner.call{value : address(this).balance}("");
		if (!success) {
			revert Raffle_TransferFailed();
		}
		emit WinnerPicked(recentWinner);
		
		
	}
	
	/* Get entrance fee */
	function getEntranceFee() public view returns (uint256){
		return i_entranceFee;
	}
	
	/* get a player*/
	function getPlayer(uint256 index) public view returns (address){
		return s_players[index];
	}
	
	/* get the recent winner*/
	function getRecentWinner() public view returns (address){
		return s_recentWinner;
	}
	/*Get raffle state*/
	function getRaffleState() public view returns (RaffleState){
		return s_raffleState;
	}
	
	function getNumWords() public view returns (uint256){
		return NUM_WORDS;
	}
	
}
// Enter the lottery (paying some amount)
// Pick a random winner
// winner to be selected every x minutes

// chainlink oracle ->randomness , automated execution (chainlink keepers)

