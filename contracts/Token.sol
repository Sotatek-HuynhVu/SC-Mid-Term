// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Token is ERC20, Ownable, ERC20Permit {
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) Ownable(_msgSender()) ERC20Permit(name) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
