// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DXTCrowdsale is Context, ReentrancyGuard, Ownable {
    // The token being sold
    IERC20 public token;

    // Address where funds are collected
    address payable public wallet;

    // Address where tokens are located
    address payable public tokenWallet;

    // How many token units a buyer gets per bnb.
    uint256 public rate = 834;

    // Min contribution
    uint256 public min = 1 ether;

    // Amount of wei raised
    uint256 public weiRaised;

    // 0 = not started
    // 1 = started
    // 2 = ended
    uint256 public saleState = 0;

    mapping(address => bool) whitelist;

    bool public whitelistEnabled = true;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokensPurchased(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );

    event SaleStateUpdated(uint256 saleState);
    event CapUpdated(uint256 cap);
    event MinUpdated(uint256 min);
    event RateUpdated(uint256 rate);
    event WhitelistEnabledUpdated(bool enabled);

    modifier whenStarted {
        require(
            saleState == 1,
            "DXTCrowdsale: Crowdsale is not currently active."
        );
        _;
    }

    modifier whenNotStarted {
        require(saleState != 1, "DXTCrowdsale: Crowdsale is currently active.");
        _;
    }

    constructor(
        address payable tokenWallet_,
        address payable wallet_,
        IERC20 token_
    ) {
        require(wallet_ != address(0), "DXTCrowdsale: wallet is 0");
        require(tokenWallet_ != address(0), "DXTCrowdsale: tokenWallet is 0");
        tokenWallet = tokenWallet_;
        wallet = wallet_;
        token = token_;
    }

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     * Note that other contracts will transfer funds with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     */
    fallback() external payable {
        buyTokens(_msgSender());
    }

    receive() external payable {
        buyTokens(_msgSender());
    }

    function setRate(uint256 rate_) public whenNotStarted onlyOwner {
        rate = rate_;
        emit RateUpdated(rate);
    }

    function setMin(uint256 min_) public onlyOwner {
        min = min_;
        emit MinUpdated(min);
    }

    function _setSaleState(uint256 saleState_) internal {
        saleState = saleState_;
        emit SaleStateUpdated(saleState);
    }

    function setSaleState(uint256 saleState_) public onlyOwner {
        require(
            saleState_ > saleState,
            "DXTCrowdsale: cannot go to previous state"
        );
        _setSaleState(saleState_);
    }

    function setWhitelistEnabled(bool enabled) public onlyOwner {
        whitelistEnabled = enabled;
        emit WhitelistEnabledUpdated(enabled);
    }

    function addWhitelistParticipants(address[] memory participants)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < participants.length; i++) {
            whitelist[participants[i]] = true;
        }
    }

    function addWhitelistParticipant(address participant) external onlyOwner {
        whitelist[participant] = true;
    }

    function removeWhitelistParticipant(address participant)
        external
        onlyOwner
    {
        whitelist[participant] = false;
    }

    function tokensRemaining() public view returns (uint256) {
        return token.allowance(tokenWallet, address(this));
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param _weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function getTokenAmount(uint256 _weiAmount)
        public
        view
        returns (
            // internal
            uint256
        )
    {
        return _weiAmount * rate;
    }

    function isWhitelisted(address beneficiary) external view returns (bool) {
        return whitelist[beneficiary];
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
     * @param _beneficiary Address performing the token purchase
     * @param _weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount)
        internal
        view
    {
        require(
            _beneficiary != address(0),
            "DXTCrowdsale: Address is the 0 address"
        );
        require(_weiAmount >= min, "DXTCrowdsale: Below minimum contribution");
        require(
            !whitelistEnabled || whitelist[_beneficiary] == true,
            "DXTCrowdsale: Not whitelisted"
        );
    }

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param beneficiary Recipient of the token purchase
     */
    function buyTokens(address beneficiary)
        public
        payable
        whenStarted
        nonReentrant
    {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);

        // calculate token amount to be sent
        uint256 tokens = getTokenAmount(weiAmount);

        // check token allowance overflow
        // this will happen when almost all tokens are sold
        uint256 allowance = tokensRemaining();
        uint256 weiToRefund = 0;
        if (tokens > allowance) {
            // refund excess bnb
            weiToRefund = (tokens - allowance) / rate;
            tokens = allowance;
        }

        weiAmount = weiAmount - weiToRefund;
        weiRaised = weiRaised + weiAmount;

        token.transferFrom(tokenWallet, beneficiary, tokens);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);

        wallet.transfer(weiAmount);

        // end crowdsale if all tokens sold
        if (tokensRemaining() <= 0) {
            _setSaleState(2);
        }

        // refund wei overflow
        if (weiToRefund > 0) {
            payable(_msgSender()).transfer(weiToRefund);
        }
    }
}
