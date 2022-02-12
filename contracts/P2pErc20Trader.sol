// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";

contract P2pErc20Trader {
    address payable public owner;

    struct Trade {
        address proposer;
        IERC20 proposerToken;
        uint256 proposerTokenAmount;
        address recipient;
        IERC20 recipientToken;
        uint256 recipientTokenAmount;
        uint256 expiration;
        bool isDeclined;
    }

    uint256 tradeIdCounter;
    mapping(uint256 => Trade) public trades;

    constructor() {
        owner = payable(msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function propose(
        address _proposerToken,
        uint256 _proposerTokenAmount,
        address _recipient,
        address _recipientToken,
        uint256 _recipientTokenAmount,
        uint256 _expiration // time until this trade will expire.
    ) external {
        require(isContract(msg.sender) && isContract(_recipient));

        trades[tradeIdCounter] = Trade({
            proposer: msg.sender,
            proposerToken: IERC20(_proposerToken),
            proposerTokenAmount: _proposerTokenAmount,
            recipient: _recipient,
            recipientToken: IERC20(_recipientToken),
            recipientTokenAmount: _recipientTokenAmount,
            expiration: block.timestamp + _expiration,
            isDeclined: false
        });

        tradeIdCounter += 1;
    }

    // Checks that both proposer and recipient of the trade have allowed amounts to be traded.
    function isTradeFunded(uint256 _tradeId) public view returns (bool) {
        Trade storage trade = trades[_tradeId];
        IERC20 proposerToken = trade.proposerToken;
        IERC20 recipientToken = trade.recipientToken;

        bool isProposerFunded = trade.proposerTokenAmount >=
            proposerToken.allowance(trade.proposer, address(this));

        bool isRecipientFunded = trade.recipientTokenAmount >=
            recipientToken.allowance(trade.recipient, address(this));

        return isProposerFunded && isRecipientFunded;
    }

    // Only the recipient of the trade may accept it.
    function accept(uint256 _tradeId) external {
        Trade storage trade = trades[_tradeId];

        require(msg.sender == trade.recipient, "Not your trade.");
        require(!trade.isDeclined, "This trade has been declined.");
        require(block.timestamp <= trade.expiration, "Trade has expired.");

        require(
            isTradeFunded(_tradeId),
            "This trade has not been funded by one or more participants."
        );

        bool success1 = trade.proposerToken.transferFrom(
            trade.proposer,
            trade.recipient,
            trade.proposerTokenAmount
        );

        bool success2 = trade.recipientToken.transferFrom(
            trade.recipient,
            trade.proposer,
            trade.recipientTokenAmount
        );

        require(success1 && success2, "Erc20 trade unsuccessful.");
    }

    // Only the proposer or recipient of the trade may decline it.
    function decline(uint256 _tradeId) external {
        address proposer = trades[_tradeId].proposer;
        address recipient = trades[_tradeId].recipient;

        require(msg.sender == proposer || msg.sender == recipient);

        trades[_tradeId].isDeclined = true;
    }

    // Get expiration of trade.
    function getExpiration(uint256 _tradeId) public view returns (uint256) {
        return trades[_tradeId].expiration;
    }

    // Get time left before trade expires.
    function getRemainingTime(uint256 _tradeId) public view returns (uint256) {
        return trades[_tradeId].expiration - block.timestamp;
    }

    // Send tips to creator.
    function tipCreator() public payable {
        (bool success, ) = owner.call{value: msg.value}("");
        require(success);
    }

    function getMiscellaneousFundsSentToContract() public {
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success);
    }

    fallback() external payable {}

    receive() external payable {}
}
