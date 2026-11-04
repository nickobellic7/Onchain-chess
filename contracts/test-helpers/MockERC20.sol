// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Test-only ERC20 with configurable decimals and a recipient blacklist
/// (transfers/mints TO a blacklisted address revert), mimicking USDC blacklisting.
contract MockERC20 is ERC20 {
    uint8 private immutable _dec;
    mapping(address => bool) public blacklisted;

    constructor(string memory n, string memory s, uint8 d) ERC20(n, s) {
        _dec = d;
    }

    function decimals() public view override returns (uint8) {
        return _dec;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setBlacklisted(address a, bool b) external {
        blacklisted[a] = b;
    }

    function _update(address from, address to, uint256 value) internal override {
        require(!blacklisted[to], "blacklisted");
        super._update(from, to, value);
    }
}
