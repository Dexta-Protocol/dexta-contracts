// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DXTCrowdsale.sol";

abstract contract Pausable is Context, Ownable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() public whenNotPaused onlyOwner {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() public whenPaused onlyOwner {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

contract DextaToken is ERC20, Pausable {
    DXTCrowdsale crowdsale;

    constructor(address to) ERC20("Dexta Token", "DXT") {
        // 10 million tokens
        _mint(to, 10000000 ether);
    }

    function setCrowdsale(DXTCrowdsale crowdsale_) public onlyOwner {
        require(
            address(crowdsale) == address(0),
            "DextaToken: crowdsale is already set"
        );
        crowdsale = crowdsale_;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public override returns (bool _success) {
        // allow transactions to be paused during presale
        // to prevent liquidity being added before presale ends
        require(
            !paused() ||
                (_from == crowdsale.tokenWallet() &&
                    crowdsale.saleState() == 1),
            "DextaToken: Transfers are currently paused."
        );
        return super.transferFrom(_from, _to, _value);
    }

    function transfer(address _to, uint256 _value)
        public
        override
        returns (bool _success)
    {
        // allow transactions to be paused during presale
        // to prevent liquidity being added before presale ends
        require(
            !paused() ||
                (_msgSender() == crowdsale.tokenWallet() &&
                    crowdsale.saleState() == 1),
            "DextaToken: Transfers are currently paused."
        );
        return super.transfer(_to, _value);
    }
}
