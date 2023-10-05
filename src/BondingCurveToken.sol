// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ERC1363} from "lib/erc1363-payable-token/contracts/token/ERC1363/ERC1363.sol";
import {ERC1363Payable} from "lib/erc1363-payable-token/contracts/payment/ERC1363Payable.sol";

/**
 * @title BondingCurveToken
 * @dev Implementation of a basic ERC20 token sale with a linear bonding curve.
 * The pricing formula follows y = mx + b where y is the token price, m is the price factor,
 * x is the total supply, and b is the base price.
 */
// contract BondingCurveToken is ERC20, ERC1363, ERC1363Payable, Ownable2Step {
contract BondingCurveToken is ERC20, Ownable2Step {

    /// @notice Event emitted when tokens are purchased.
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);

    /// @notice Event emitted when tokens are sold.
    event TokensSold(address indexed seller, uint256 amount, uint256 revenue);

    /// @notice Event emitted when excess ether is withdrawn by the owner.
    event ExcessWithdrawn(address indexed owner, uint256 amount);

    /// @notice Event emitted when the sell lockup time is updated.
    event SellLockupTimeUpdated(uint256 newLockupTime);

    /// @notice Base price of token
    uint256 public constant BASE_PRICE = 0 ether; 

    /// @notice Price increase factor per token.
    uint256 public constant PRICE_FACTOR = 1 ether; // 1 ether

    /// @notice Reserve of Ether in the contract.
    uint256 private _reserve;

    /// @notice The time delay required before tokens can be sold, to prevent flash loan attacks.
    uint256 public sellLockupTime = 5 minutes;  // Owner can adjust the lockup time as needed

    /// @notice Keeps track of the last time tokens were purchased per address.
    mapping(address => uint256) private lastPurchaseTime;

    /**
     * @dev Constructor that initializes the BondingCurveToken.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     */
    constructor(string memory name, string memory symbol) 
        ERC20(name, symbol) 
        // ERC1363Payable(this)  // self-reference as it is its own accepted token
    {}

    // function supportsInterface(bytes4 interfaceId) public view override(ERC1363, ERC1363Payable) returns (bool) {
    //     return ERC1363.supportsInterface(interfaceId) || ERC1363Payable.supportsInterface(interfaceId);
    // }

    /**
     * @dev Handles the receipt of ERC1363 tokens and triggers a token sale.
     * @param operator The operator triggering the transfer.
     * @param from The sender of tokens.
     * @param amount The amount of tokens sent.
     * @param data Additional data with no specified format.
     */
    // function _transferReceived(
    //     address operator, 
    //     address from, 
    //     uint256 amount, 
    //     bytes memory data
    // ) internal override {
    //     sellTokens(from, amount);  
    // }

    /**
     * @dev Allows users to purchase tokens with Ether, based on the current price from the bonding curve.
     * Users can specify the number of tokens they wish to purchase.
     * @param tokenAmount The number of tokens the user wants to purchase.
     */
    function buyTokens(uint256 tokenAmount) external payable {
        require(tokenAmount > 0, "Cannot purchase zero tokens");

        uint256 currentSupply = totalSupply();
        uint256 newSupply = currentSupply + tokenAmount;

        // Pricing formula for linear bonding curve: y = mx + b
        uint256 cost = (newSupply**2 - currentSupply**2) / 2;

        require(msg.value >= cost, "Insufficient ether sent");

        _mint(msg.sender, tokenAmount);
        lastPurchaseTime[msg.sender] = block.timestamp;
        _reserve += cost;

        // Refund excess ether
        uint256 excess = msg.value - cost;
        if (excess > 0) {
            (bool sent, ) = payable(msg.sender).call{value: excess}("");
            require(sent, "Failed to refund excess ether");
        }

        emit TokensPurchased(msg.sender, tokenAmount, cost);
    }

    /**
     * @dev Allows users to sell their tokens and receive Ether in return,
     * based on the current price from the bonding curve.
     * @param tokenAmount The number of tokens the user wants to sell.
     */
    function sellTokens(uint256 tokenAmount) public {
        require(tokenAmount > 0, "Cannot sell zero tokens");
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient tokens");
        require(block.timestamp >= lastPurchaseTime[msg.sender] + sellLockupTime, "Tokens are locked up");

        uint256 currentSupply = totalSupply();
        uint256 newSupply = currentSupply - tokenAmount;

        // Updated pricing formula for selling
        uint256 revenue = (currentSupply**2 - newSupply**2) / 2;

        _burn(msg.sender, tokenAmount);
        _reserve -= revenue;
        (bool sent, ) = payable(msg.sender).call{value: revenue}("");
        require(sent, "Failed to send Ether");

        emit TokensSold(msg.sender, tokenAmount, revenue);
    }

    /**
     * @notice Calculates the current price of the token based on the bonding curve.
     * @return The current price per token.
     */
    function getCurrentPrice() public view returns (uint256) {
        return BASE_PRICE + PRICE_FACTOR * totalSupply();
    }

    /**
     * @dev Allows the contract owner to withdraw any excess Ether that is not part of the reserve.
     */
    function withdrawExcess() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > _reserve, "No excess Ether to withdraw");

        uint256 excess = balance - _reserve;
        (bool sent, ) = payable(owner()).call{value: excess}("");
        require(sent, "Failed to withdraw Ether");

        emit ExcessWithdrawn(owner(), excess);
    }

    /**
     * @notice Estimates the cost to purchase a given number of tokens.
     * @param tokenAmount The number of tokens the user wishes to purchase.
     * @return The estimated cost in Ether to purchase the given number of tokens.
     */
    function getCostForTokens(uint256 tokenAmount) public view returns (uint256) {
        require(tokenAmount > 0, "Cannot estimate zero tokens");

        uint256 currentSupply = totalSupply();
        uint256 newSupply = currentSupply + tokenAmount;

        // Calculate the estimated cost based on the bonding curve formula
        uint256 estimatedCost = (newSupply**2 - currentSupply**2) / 2;

        return estimatedCost;
    }

    /**
     * @notice Estimates the revenue from selling a given number of tokens.
     * @param tokenAmount The number of tokens the user wishes to sell.
     * @return The estimated revenue in Ether from selling the given number of tokens.
     */
    function getRevenueForTokens(uint256 tokenAmount) public view returns (uint256) {
        require(tokenAmount > 0, "Cannot estimate zero tokens");
        require(tokenAmount <= totalSupply(), "Token amount exceeds total supply");

        uint256 currentSupply = totalSupply();
        uint256 newSupply = currentSupply - tokenAmount;

        // Calculate the estimated revenue based on the bonding curve formula
        uint256 estimatedRevenue = (currentSupply**2 - newSupply**2) / 2;

        return estimatedRevenue;
    }

    /**
     * @notice Retrieves the amount of Ether held in reserve.
     * @return The amount of Ether in reserve.
     */
    function getReserve() external view returns (uint256) {
        return _reserve;
    }

    /**
     * @dev Updates the sell lockup time.
     * @param newLockupTime The new lockup time in seconds.
     */
    function updateSellLockupTime(uint256 newLockupTime) external onlyOwner {
        sellLockupTime = newLockupTime;
        emit SellLockupTimeUpdated(newLockupTime);

    }

    // Helper function to calculate square root
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /**
     * @dev Function that is called when Ether is sent directly to the contract address.
     */
    receive() external payable {
        uint256 currentSupply = totalSupply();
        uint256 etherSent = msg.value;

        // Calculate the final supply after purchasing tokens with the sent Ether
        uint256 finalSupply = sqrt((2 * etherSent / PRICE_FACTOR) + currentSupply**2);

        require(finalSupply >= currentSupply, "Invalid final supply calculated");

        uint256 tokenAmount = finalSupply - currentSupply;

        require(tokenAmount > 0, "Cannot purchase zero tokens");

        _mint(msg.sender, tokenAmount);
        _reserve += etherSent;

        emit TokensPurchased(msg.sender, tokenAmount, etherSent);
    }
}
