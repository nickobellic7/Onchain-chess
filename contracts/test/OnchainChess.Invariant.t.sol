// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {OnchainChess} from "../OnchainChess.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";
import {OnchainChessTestBase} from "./OnchainChess.Base.t.sol";

/// @dev Bounded random-action driver. Plain (non-try) calls: reverts are discarded by the fuzzer.
contract ChessHandler is Test {
    OnchainChess public chess;
    MockERC20 public usdc;
    address[3] public actors;

    constructor(OnchainChess c, MockERC20 u, address[3] memory a) {
        chess = c;
        usdc = u;
        actors = a;
    }

    function _actor(uint256 i) internal view returns (address) {
        return actors[i % 3];
    }

    function _id(uint256 raw) internal view returns (uint256) {
        uint256 n = chess.gameCount();
        return n == 0 ? 0 : bound(raw, 1, n);
    }

    function create(uint256 who, uint128 wager, uint32 timeout, bool white, bool invite, uint256 invitee) external {
        wager = uint128(bound(wager, 0, 50e6));
        timeout = uint32(bound(timeout, 60, 30 days));
        address inv = invite ? _actor(invitee) : address(0);
        vm.prank(_actor(who));
        chess.createGame(wager, timeout, white, inv);
    }

    function join(uint256 idRaw, uint256 who) external {
        uint256 id = _id(idRaw);
        vm.prank(_actor(who));
        chess.joinGame(id);
    }

    function cancel(uint256 idRaw, uint256 who) external {
        uint256 id = _id(idRaw);
        vm.prank(_actor(who));
        chess.cancelGame(id);
    }

    function resign(uint256 idRaw, uint256 who) external {
        uint256 id = _id(idRaw);
        vm.prank(_actor(who));
        chess.resign(id);
    }

    function offerDraw(uint256 idRaw, uint256 who) external {
        uint256 id = _id(idRaw);
        vm.prank(_actor(who));
        chess.offerDraw(id);
    }

    function acceptDraw(uint256 idRaw, uint256 who) external {
        uint256 id = _id(idRaw);
        vm.prank(_actor(who));
        chess.acceptDraw(id);
    }

    function claimTimeout(uint256 idRaw, uint256 dt) external {
        uint256 id = _id(idRaw);
        skip(bound(dt, 0, 2 days));
        chess.claimTimeout(id);
    }

    function move(uint256 idRaw, uint256 seed) external {
        uint256 id = _id(idRaw);
        OnchainChess.Game memory g = chess.getGame(id);
        for (uint256 i; i < 64; ++i) {
            uint8 from = uint8((seed + i) % 64);
            uint64 mask = chess.legalTargets(g.board, g.whiteToMove, from);
            if (mask == 0) continue;
            uint8 to;
            uint256 n = uint256(keccak256(abi.encode(seed))) % 28;
            for (uint8 t; t < 64; ++t) {
                if ((mask >> t) & 1 == 1) {
                    to = t;
                    if (n == 0) break;
                    --n;
                }
            }
            vm.prank(g.whiteToMove ? g.white : g.black);
            uint8 piece = uint8((g.board >> (uint256(from) * 4)) & 15);
            bool promo = (piece & 7) == 1 && (to / 8 == (g.whiteToMove ? 7 : 0));
            chess.makeMove(id, from, to, promo ? 5 : 0);
            return;
        }
    }

    function setBlacklist(uint256 who, bool flag) external {
        usdc.setBlacklisted(_actor(who), flag);
    }

    function withdraw(uint256 who) external {
        vm.prank(_actor(who));
        chess.withdrawOwed();
    }
}

contract OnchainChessInvariantTest is OnchainChessTestBase {
    ChessHandler internal handler;
    address[3] internal actorList;

    function setUp() public override {
        super.setUp();
        actorList = [alice, bob, carol];
        handler = new ChessHandler(chess, usdc, actorList);
        targetContract(address(handler));
    }

    /// Conservation: token held == escrowed wagers of live games + unpaid credits.
    function invariant_TokenBalanceEqualsEscrowPlusOwed() public view {
        uint256 locked;
        uint256 n = chess.gameCount();
        for (uint256 id = 1; id <= n; ++id) {
            OnchainChess.Game memory g = chess.getGame(id);
            if (g.status == OnchainChess.Status.Open) locked += g.wager;
            else if (g.status == OnchainChess.Status.Active) locked += 2 * uint256(g.wager);
        }
        uint256 owedSum;
        for (uint256 i; i < 3; ++i) owedSum += chess.owed(actorList[i]);
        assertEq(usdc.balanceOf(address(chess)), locked + owedSum);
    }

    /// Status / endReason / winner are mutually consistent for every game.
    function invariant_TerminalStatesAreConsistent() public view {
        uint256 n = chess.gameCount();
        for (uint256 id = 1; id <= n; ++id) {
            OnchainChess.Game memory g = chess.getGame(id);
            if (g.status == OnchainChess.Status.Open || g.status == OnchainChess.Status.Active) {
                assertEq(uint8(g.endReason), 0);
                assertEq(g.winner, address(0));
            } else if (g.status == OnchainChess.Status.Cancelled) {
                assertEq(uint8(g.endReason), uint8(OnchainChess.EndReason.Cancelled));
                assertEq(g.winner, address(0));
            } else {
                assertTrue(g.endReason != OnchainChess.EndReason.None);
                assertTrue(g.endReason != OnchainChess.EndReason.Cancelled);
                if (g.endReason == OnchainChess.EndReason.DrawAgreed) assertEq(g.winner, address(0));
                else assertTrue(g.winner == g.white || g.winner == g.black);
            }
        }
    }
}
