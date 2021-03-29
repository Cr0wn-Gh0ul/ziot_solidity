//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";

contract Gamble {
    using SafeERC20 for IERC20;

    struct Bet {
        uint256 blockNumber;
        uint256 amount;
        uint256 choice;
    }

    mapping(address => Bet) public bets;

    uint256 public MAX_BET_AMOUNT_PERCENT;
    uint256 public PERCENT_FEE;
    uint256 public BANK_ROLL;
    bool public IS_OPEN;

    address public owner;
    IERC20 public ziotAddress = IERC20(0xfB22cED41B1267dA411F68c879f4Defd0bD4796a);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    event betPlaced(address user, uint256 choice, uint256 betAmount);
    event betResolved(address user, bool winner, uint256 amount);
    constructor() {
        owner = msg.sender;
        MAX_BET_AMOUNT_PERCENT = 25;
        PERCENT_FEE = 10;
        BANK_ROLL = 0;
    }

    function updateSettings(
        uint256 _maxBetAmountPercent,
        uint256 _percentFee,
        bool _isOpen
    ) public onlyOwner returns (bool) {
        require(
            _maxBetAmountPercent > 1 &&
                _maxBetAmountPercent < 100 &&
                _percentFee > 1 &&
                _percentFee < 100
        );
        MAX_BET_AMOUNT_PERCENT = _maxBetAmountPercent;
        PERCENT_FEE = _percentFee;
        IS_OPEN = _isOpen;
        return true;
    }

    function withdrawFunds(uint256 _amount, address _withdrawAddress)
        external
        onlyOwner
        returns (bool)
    {
        ziotAddress.safeTransfer(_withdrawAddress, _amount);
        BANK_ROLL -= _amount;
        return true;
    }

    function initializeBankroll() public onlyOwner {
        BANK_ROLL = ziotAddress.balanceOf(address(this));
        IS_OPEN = true;
    }

    function gamble(uint256 _amount, uint256 _userChoice)
        external
        returns (bool)
    {
        uint256 maxBetAmount = (BANK_ROLL * MAX_BET_AMOUNT_PERCENT) / 100;
        require(_amount > 0);
        require(_userChoice == 0 || _userChoice == 1);
        require(IS_OPEN == true);
        require(bets[msg.sender].blockNumber == 0);
        require(_amount <= maxBetAmount);
        ziotAddress.safeTransferFrom(msg.sender, address(this), _amount);
        bets[msg.sender].blockNumber = block.number;
        bets[msg.sender].choice = _userChoice;
        bets[msg.sender].amount = _amount;
        BANK_ROLL += _amount;
        emit betPlaced(msg.sender, _userChoice, _amount);
        return true;
    }

    function getWinner() external returns (bool) {
        if (canResolveBet()) {
            if (
                (uint256(blockhash(bets[msg.sender].blockNumber + 5)) % 2) ==
                bets[msg.sender].choice
            ) {
                uint256 amountSendBack =
                    ((bets[msg.sender].amount * (100 - PERCENT_FEE)) / 100) * 2;
                ziotAddress.safeTransfer(msg.sender, amountSendBack);
                BANK_ROLL -= amountSendBack;
                delete bets[msg.sender];
                emit betResolved(msg.sender, true, amountSendBack);
                return true;
            } else {
                delete bets[msg.sender];
                emit betResolved(msg.sender, false, 0);
                return false;
            }
        } else {
            delete bets[msg.sender];
            emit betResolved(msg.sender, false, 0);            
            return false;
        }
    }

    function canResolveBet() public view returns (bool) {
        require(bets[msg.sender].blockNumber != 0, "No bets pending.");
        require(IS_OPEN == true);
                require(
            block.number > bets[msg.sender].blockNumber + 5,
            "Not enough blocks have passed."
        );
        if (block.number < bets[msg.sender].blockNumber + 250) {
            return true;
        } else {
            return false;
        }
    }
}
