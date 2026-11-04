// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OnchainChess} from "../OnchainChess.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";

abstract contract OnchainChessTestBase is Test {
    OnchainChess internal chess;
    MockERC20 internal usdc;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");

    uint128 internal constant WAGER = 10e6;
    uint32 internal constant TIMEOUT = 1 hours;
    uint256 internal constant FUNDS = 1_000e6;

    // piece nibbles
    uint8 internal constant WP = 1;
    uint8 internal constant WN = 2;
    uint8 internal constant WB = 3;
    uint8 internal constant WR = 4;
    uint8 internal constant WQ = 5;
    uint8 internal constant WK = 6;
    uint8 internal constant BP = 9;
    uint8 internal constant BN = 10;
    uint8 internal constant BB = 11;
    uint8 internal constant BR = 12;
    uint8 internal constant BQ = 13;
    uint8 internal constant BK = 14;

    function setUp() public virtual {
        usdc = new MockERC20("Mock USDC", "mUSDC", 6);
        chess = new OnchainChess(IERC20(address(usdc)));
        address[4] memory users = [alice, bob, carol, dave];
        for (uint256 i; i < 4; ++i) {
            usdc.mint(users[i], FUNDS);
            vm.prank(users[i]);
            usdc.approve(address(chess), type(uint256).max);
        }
    }

    // ---------- square / board helpers ----------

    /// @dev "e4" => 28
    function sq(string memory n) internal pure returns (uint8) {
        bytes memory b = bytes(n);
        require(b.length == 2, "bad square");
        return (uint8(b[0]) - 97) + (uint8(b[1]) - 49) * 8;
    }

    /// @dev Space-separated squares, e.g. "e3 e4" => bitmask. "" => 0.
    function bits(string memory s) internal pure returns (uint64 m) {
        bytes memory b = bytes(s);
        for (uint256 i; i + 1 < b.length; i += 3) {
            uint8 f = uint8(b[i]) - 97;
            uint8 r = uint8(b[i + 1]) - 49;
            m |= uint64(1) << (r * 8 + f);
        }
    }

    function put(uint256 board, string memory n, uint8 piece) internal pure returns (uint256) {
        uint256 sh = uint256(sq(n)) * 4;
        return (board & ~(uint256(15) << sh)) | (uint256(piece) << sh);
    }

    function pieceAt(uint256 board, uint8 square) internal pure returns (uint8) {
        return uint8((board >> (uint256(square) * 4)) & 15);
    }

    function initialBoard() internal pure returns (uint256 b) {
        uint8[8] memory back = [4, 2, 3, 5, 6, 3, 2, 4];
        for (uint256 f; f < 8; ++f) {
            b |= uint256(back[f]) << (f * 4);
            b |= uint256(1) << ((8 + f) * 4);
            b |= uint256(9) << ((48 + f) * 4);
            b |= uint256(back[f] | 8) << ((56 + f) * 4);
        }
    }

    function targets(uint256 board, bool white, string memory from) internal view returns (uint64) {
        return chess.legalTargets(board, white, sq(from));
    }

    // ---------- game helpers (alice = white, bob = black) ----------

    function newGame() internal returns (uint256 id) {
        vm.prank(alice);
        id = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.prank(bob);
        chess.joinGame(id);
    }

    function wm(uint256 id, string memory from, string memory to) internal {
        vm.prank(alice);
        chess.makeMove(id, sq(from), sq(to), 0);
    }

    function bm(uint256 id, string memory from, string memory to) internal {
        vm.prank(bob);
        chess.makeMove(id, sq(from), sq(to), 0);
    }

    function wp(uint256 id, string memory from, string memory to, uint8 promo) internal {
        vm.prank(alice);
        chess.makeMove(id, sq(from), sq(to), promo);
    }

    function bp(uint256 id, string memory from, string memory to, uint8 promo) internal {
        vm.prank(bob);
        chess.makeMove(id, sq(from), sq(to), promo);
    }

    function game(uint256 id) internal view returns (OnchainChess.Game memory) {
        return chess.getGame(id);
    }
}
