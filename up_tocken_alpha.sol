// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";

/*
 *  FollowUPToken - Because everyone needs an AI-Secretary with a dash of cosmic pricing.
 *  This token uses a “bonding curve” with a funky twist. The more tokens minted,
 *  the higher the price gets (and there's a little extra spice).
 */
contract FollowUPToken is Ownable, ReentrancyGuard {
    // Basic token stuff
    string public name = "FollowUP";
    string public symbol = "FUP";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    // The absolute max you can ever dream to mint (in token units, ignoring decimals).
    uint256 public maxSupply;
    
    // Where we store how many tokens each address has
    mapping(address => uint256) public balanceOf;
    
    // Pricing parameters for our “fancy” bonding curve
    // basePrice is the base cost (in wei) per token. E.g. 0.001 ETH = 1e15
    uint256 public basePrice = 1e15; // 0.001 ETH
    // priceIncrement is how much the cost increases per token sold. E.g. 0.00001 ETH = 1e13
    uint256 public priceIncrement = 1e13; // 0.00001 ETH

    // Some logs so we can see what’s happening
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event Withdrawal(address indexed owner, uint256 amount);

    /*
     * Constructor: set the maximum possible supply of tokens.
     * _maxSupply is given in plain token units (no decimals).
     * We'll multiply it by 10^decimals inside.
     */
    constructor(uint256 _maxSupply) {
        require(_maxSupply > 0, "Gotta have some non-zero max supply");
        maxSupply = _maxSupply * 10 ** uint256(decimals);
    }
    
    /*
     * getPrice: calculates the cost for _numTokens using our cosmic formula.
     * Original bond formula:
     *   cost = (_numTokens * basePrice)
     *           + priceIncrement * ( _numTokens * (2*totalSupply + _numTokens - 1) ) / 2
     *
     * Then we add a tiny cosmic factor based on how big totalSupply is getting.
     */
    function getPrice(uint256 _numTokens) public view returns (uint256 cost) {
        uint256 currentSupply = totalSupply;

        // The good old linear bonding part
        cost = _numTokens * basePrice
            + priceIncrement * (_numTokens * (2 * currentSupply + _numTokens - 1)) / 2;
        
        // Funky cosmic factor: the bigger totalSupply grows, the pricier it gets.
        // Tweak this line if you want more or less cosmic effect.
        cost += ( (currentSupply + 1) * _numTokens ) / 1000;
    }
    
    /*
     * buyTokens: Pay up and get your tokens. 
     *   - Checks that you're not exceeding maxSupply
     *   - Uses nonReentrant to block reentry shenanigans
     *   - If you overpay, you get a refund
     */
    function buyTokens(uint256 _numTokens) public payable nonReentrant {
        require(_numTokens > 0, "Need to buy at least 1 token, friend");
        require(totalSupply + _numTokens <= maxSupply, "That would blow past max supply");
        
        uint256 cost = getPrice(_numTokens);
        require(msg.value >= cost, "Not enough Ether to cover the cosmic cost");

        // Mint them right here
        totalSupply += _numTokens;
        balanceOf[msg.sender] += _numTokens;
        
        // Refund any leftover Ether
        uint256 excess = msg.value - cost;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
        
        emit Transfer(address(0), msg.sender, _numTokens);
        emit TokensPurchased(msg.sender, _numTokens, cost);
    }
    
    /*
     * withdrawFunds: Owner can pull out the Ether that people have paid.
     *   - Check that there's actually some balance to withdraw
     *   - nonReentrant to be safe
     */
    function withdrawFunds() public onlyOwner nonReentrant {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No Ether left to withdraw, sorry");
        payable(owner()).transfer(contractBalance);
        emit Withdrawal(owner(), contractBalance);
    }
    
    /*
     * fallback + receive: We reject direct Ether transfers,
     * because we only want them to come through buyTokens.
     */
    fallback() external payable {
        revert("No direct Ether allowed, buddy. Use buyTokens()");
    }
    
    receive() external payable {
        revert("No direct Ether allowed, buddy. Use buyTokens()");
    }
}
