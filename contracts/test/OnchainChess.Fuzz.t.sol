// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OnchainChess} from "../OnchainChess.sol";
import {OnchainChessTestBase} from "./OnchainChess.Base.t.sol";

contract OnchainChessFuzzTest is OnchainChessTestBase {
    // ---------- generators / helpers ----------

    /// @dev Random board of only valid nibbles (0, 1..6, 9..14), ~50% empty.
    function _randomBoard(uint256 seed) internal pure returns (uint256 board) {
        for (uint256 i; i < 64; ++i) {
            uint256 h = uint256(keccak256(abi.encode(seed, i)));
            if (h % 2 == 0) continue;
            uint8 v = uint8((h >> 8) % 12);
            uint8 piece = v < 6 ? v + 1 : v + 3;
            board |= uint256(piece) << (i * 4);
        }
    }

    function _popcount(uint64 m) internal pure returns (uint256 n) {
        while (m != 0) {
            m &= m - 1;
            ++n;
        }
    }

    function _nthBit(uint64 m, uint256 n) internal pure returns (uint8) {
        n = n % _popcount(m);
        for (uint8 i; i < 64; ++i) {
            if ((m >> i) & 1 == 1) {
                if (n == 0) return i;
                --n;
            }
        }
        revert("unreachable");
    }

    /// @dev First square at or after seed%64 (wrapping) owning at least one legal target.
    function _pickMover(uint256 board, bool white, uint256 seed)
        internal
        view
        returns (bool found, uint8 from, uint64 mask)
    {
        uint256 start = seed % 64;
        for (uint256 i; i < 64; ++i) {
            from = uint8((start + i) % 64);
            mask = chess.legalTargets(board, white, from);
            if (mask != 0) return (true, from, mask);
        }
    }

    function _isPromotion(uint256 board, bool white, uint8 from, uint8 to) internal pure returns (bool) {
        uint8 p = pieceAt(board, from);
        return (p & 7) == 1 && (to / 8 == (white ? 7 : 0));
    }

    /// @dev Advance a game with pseudo-random legal moves; every one MUST succeed.
    function _advance(uint256 gid, uint256 seed, uint256 plies) internal {
        for (uint256 k; k < plies; ++k) {
            OnchainChess.Game memory g = chess.getGame(gid);
            if (g.status != OnchainChess.Status.Active) return;
            (bool found, uint8 from,) = _pickMover(g.board, g.whiteToMove, uint256(keccak256(abi.encode(seed, k))));
            if (!found) return;
            uint64 mask = chess.legalTargets(g.board, g.whiteToMove, from);
            uint8 to = _nthBit(mask, uint256(keccak256(abi.encode(seed, k, "to"))));
            uint8 promo = _isPromotion(g.board, g.whiteToMove, from, to) ? uint8(2 + (seed >> k) % 4) : 0;
            vm.prank(g.whiteToMove ? g.white : g.black);
            chess.makeMove(gid, from, to, promo); // a legalTargets bit must always be playable
        }
    }

    // ---------- properties ----------

    /// legalTargets never includes own pieces, the origin, or anything for a non-side piece.
    function testFuzz_LegalTargetsNeverIncludeOwnPieces(uint256 seed, bool white, uint8 fromRaw) public view {
        uint256 board = _randomBoard(seed);
        uint8 from = uint8(bound(fromRaw, 0, 63));
        uint64 mask = chess.legalTargets(board, white, from);

        uint8 mover = pieceAt(board, from);
        bool isSidePiece = mover != 0 && ((mover & 8) == 0) == white;
        if (!isSidePiece) assertEq(mask, 0);

        for (uint8 i; i < 64; ++i) {
            if ((mask >> i) & 1 == 0) continue;
            assertTrue(i != from, "origin in mask");
            uint8 occ = pieceAt(board, i);
            if (occ != 0) {
                bool occIsWhite = (occ & 8) == 0;
                assertTrue(occIsWhite != white, "own piece in mask");
            }
        }
    }

    /// Same property over every origin of a random board (denser coverage).
    function testFuzz_LegalTargetsNeverIncludeOwnPieces_AllOrigins(uint256 seed, bool white) public view {
        uint256 board = _randomBoard(seed);
        for (uint8 from; from < 64; ++from) {
            uint64 mask = chess.legalTargets(board, white, from);
            for (uint8 i; i < 64; ++i) {
                if ((mask >> i) & 1 == 0) continue;
                uint8 occ = pieceAt(board, i);
                if (occ != 0) assertTrue(((occ & 8) == 0) != white, "own piece in mask");
            }
        }
    }

    /// makeMove succeeds iff the target bit is set in legalTargets (promotion supplied when needed).
    function testFuzz_MakeMoveSucceedsIffTargetBitSet(
        uint256 seed,
        uint8 plies,
        bool useMover,
        bool biasTo,
        uint8 fromRaw,
        uint8 toRaw
    ) public {
        uint256 gid = newGame();
        _advance(gid, seed, bound(plies, 0, 14));

        OnchainChess.Game memory g = chess.getGame(gid);
        if (g.status != OnchainChess.Status.Active) return;

        uint8 from = uint8(bound(fromRaw, 0, 63));
        if (useMover) {
            (bool found, uint8 f,) = _pickMover(g.board, g.whiteToMove, seed >> 7);
            if (found) from = f;
        }
        uint64 mask = chess.legalTargets(g.board, g.whiteToMove, from);
        uint8 to = (biasTo && mask != 0) ? _nthBit(mask, toRaw) : uint8(bound(toRaw, 0, 63));

        uint8 promo = _isPromotion(g.board, g.whiteToMove, from, to) ? 5 : 0;
        bool ok;
        vm.prank(g.whiteToMove ? g.white : g.black);
        try chess.makeMove(gid, from, to, promo) {
            ok = true;
        } catch {
            ok = false;
        }
        assertEq(ok, (mask >> to) & 1 == 1, "makeMove success != target bit");

        if (ok) {
            OnchainChess.Game memory a = chess.getGame(gid);
            assertEq(a.moveCount, g.moveCount + 1);
            assertEq(pieceAt(a.board, from), 0);
            assertEq(pieceAt(a.board, to), promo != 0 ? (pieceAt(g.board, from) & 8) | promo : pieceAt(g.board, from));
        }
    }

    /// A move onto a non-promotion square with a nonzero promotion is rejected; correct moves aren't.
    function testFuzz_NonPromotionMoveRejectsPromotionArg(uint256 seed, uint8 promo) public {
        promo = uint8(bound(promo, 1, 255));
        uint256 gid = newGame();
        _advance(gid, seed, 6);
        OnchainChess.Game memory g = chess.getGame(gid);
        if (g.status != OnchainChess.Status.Active) return;
        (bool found, uint8 from, uint64 mask) = _pickMover(g.board, g.whiteToMove, seed);
        if (!found) return;
        uint8 to = _nthBit(mask, seed >> 3);
        if (_isPromotion(g.board, g.whiteToMove, from, to)) return;
        vm.prank(g.whiteToMove ? g.white : g.black);
        vm.expectRevert(OnchainChess.InvalidPromotion.selector);
        chess.makeMove(gid, from, to, promo);
    }

    /// Promotion square: only types 2..5 accepted.
    function testFuzz_PromotionTypeValidity(uint8 promo) public {
        // Black pawn b2 about to promote (reachable by the scripted sequence).
        uint256 gid = newGame();
        wm(gid, "h2", "h3");
        bm(gid, "a7", "a5");
        wm(gid, "h3", "h4");
        bm(gid, "a5", "a4");
        wm(gid, "h4", "h5");
        bm(gid, "a4", "a3");
        wm(gid, "h5", "h6");
        bm(gid, "a3", "b2");
        wm(gid, "h6", "g7");
        vm.prank(bob);
        if (promo < 2 || promo > 5) vm.expectRevert(OnchainChess.InvalidPromotion.selector);
        chess.makeMove(gid, sq("b2"), sq("a1"), promo);
        if (promo >= 2 && promo <= 5) assertEq(pieceAt(chess.getGame(gid).board, sq("a1")), 8 | promo);
    }

    /// Wager conservation: resign pays winner exactly 2x wager, nothing stuck.
    function testFuzz_ResignPaysDoubleWager(uint128 wager, bool whiteResigns) public {
        wager = uint128(bound(wager, 0, FUNDS));
        vm.prank(alice);
        uint256 gid = chess.createGame(wager, TIMEOUT, true, address(0));
        vm.prank(bob);
        chess.joinGame(gid);
        assertEq(usdc.balanceOf(address(chess)), 2 * uint256(wager));

        vm.prank(whiteResigns ? alice : bob);
        chess.resign(gid);

        address winner = whiteResigns ? bob : alice;
        address loser = whiteResigns ? alice : bob;
        assertEq(usdc.balanceOf(winner), FUNDS + wager);
        assertEq(usdc.balanceOf(loser), FUNDS - wager);
        assertEq(usdc.balanceOf(address(chess)), 0);
    }

    /// Draw refunds exactly; cancel refunds exactly.
    function testFuzz_DrawAndCancelRefundExactly(uint128 wager) public {
        wager = uint128(bound(wager, 0, FUNDS));
        vm.prank(alice);
        uint256 g1 = chess.createGame(wager, TIMEOUT, true, address(0));
        vm.prank(alice);
        chess.cancelGame(g1);
        assertEq(usdc.balanceOf(alice), FUNDS);

        vm.prank(alice);
        uint256 g2 = chess.createGame(wager, TIMEOUT, true, address(0));
        vm.prank(bob);
        chess.joinGame(g2);
        vm.prank(alice);
        chess.offerDraw(g2);
        vm.prank(bob);
        chess.acceptDraw(g2);
        assertEq(usdc.balanceOf(alice), FUNDS);
        assertEq(usdc.balanceOf(bob), FUNDS);
        assertEq(usdc.balanceOf(address(chess)), 0);
    }

    /// Timeout boundary for any valid timeout.
    function testFuzz_TimeoutBoundary(uint32 timeout) public {
        timeout = uint32(bound(timeout, 60, 30 days));
        vm.prank(alice);
        uint256 gid = chess.createGame(0, timeout, true, address(0));
        vm.prank(bob);
        chess.joinGame(gid);
        uint256 t0 = block.timestamp;

        vm.warp(t0 + timeout);
        vm.expectRevert(OnchainChess.NotTimedOut.selector);
        chess.claimTimeout(gid);

        vm.warp(t0 + timeout + 1);
        vm.prank(alice);
        vm.expectRevert(OnchainChess.MoveTimedOut.selector);
        chess.makeMove(gid, sq("e2"), sq("e4"), 0);
        chess.claimTimeout(gid);
        assertEq(game(gid).winner, bob);
    }
}
