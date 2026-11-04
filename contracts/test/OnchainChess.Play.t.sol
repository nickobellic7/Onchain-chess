// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OnchainChess} from "../OnchainChess.sol";
import {OnchainChessTestBase} from "./OnchainChess.Base.t.sol";

/// @dev makeMove: turn order, reverts, piece moves, promotion, king capture.
contract OnchainChessPlayTest is OnchainChessTestBase {
    uint256 internal id;

    function setUp() public override {
        super.setUp();
        id = newGame();
    }

    // ---------- successful moves ----------

    function test_Move_UpdatesBoardTurnCounterAndTimer() public {
        skip(100);
        wm(id, "e2", "e4");
        OnchainChess.Game memory g = game(id);
        assertEq(pieceAt(g.board, sq("e2")), 0);
        assertEq(pieceAt(g.board, sq("e4")), WP);
        assertFalse(g.whiteToMove);
        assertEq(g.moveCount, 1);
        assertEq(g.lastMoveAt, uint40(block.timestamp));
        assertEq(uint8(g.status), uint8(OnchainChess.Status.Active));
    }

    function test_Move_EmitsMoveMade() public {
        vm.expectEmit(true, true, false, true, address(chess));
        emit OnchainChess.MoveMade(id, alice, sq("g1"), sq("f3"), WN, 0, 0, 1);
        wm(id, "g1", "f3");
    }

    function test_Move_CaptureReportsCapturedPiece() public {
        wm(id, "e2", "e4");
        bm(id, "d7", "d5");
        vm.expectEmit(true, true, false, true, address(chess));
        emit OnchainChess.MoveMade(id, alice, sq("e4"), sq("d5"), WP, BP, 0, 3);
        wm(id, "e4", "d5");
        assertEq(pieceAt(game(id).board, sq("d5")), WP);
        assertEq(pieceAt(game(id).board, sq("e4")), 0);
    }

    function test_Move_EveryPieceTypeCanMove() public {
        wm(id, "e2", "e4"); // pawn double
        bm(id, "e7", "e5");
        wm(id, "f1", "c4"); // bishop
        bm(id, "f8", "c5");
        wm(id, "d1", "h5"); // queen
        bm(id, "d8", "h4");
        wm(id, "g1", "f3"); // knight
        bm(id, "g8", "f6");
        wm(id, "h1", "f1"); // rook
        bm(id, "h8", "f8");
        wm(id, "e1", "e2"); // king
        bm(id, "e8", "e7");
        OnchainChess.Game memory g = game(id);
        assertEq(g.moveCount, 12);
        assertEq(pieceAt(g.board, sq("e2")), WK);
        assertEq(pieceAt(g.board, sq("e7")), BK);
        assertEq(pieceAt(g.board, sq("c4")), WB);
        assertEq(pieceAt(g.board, sq("h5")), WQ);
        assertEq(pieceAt(g.board, sq("f1")), WR);
        assertEq(pieceAt(g.board, sq("f3")), WN);
        assertTrue(g.whiteToMove);
    }

    // ---------- turn order & illegal ----------

    function test_Move_RevertsWhenNotYourTurn() public {
        vm.prank(bob);
        vm.expectRevert(OnchainChess.NotYourTurn.selector);
        chess.makeMove(id, sq("e7"), sq("e5"), 0);

        wm(id, "e2", "e4");
        vm.prank(alice);
        vm.expectRevert(OnchainChess.NotYourTurn.selector);
        chess.makeMove(id, sq("d2"), sq("d4"), 0);
    }

    function test_Move_RevertsForNonPlayer() public {
        vm.prank(carol);
        vm.expectRevert(OnchainChess.NotYourTurn.selector);
        chess.makeMove(id, sq("e2"), sq("e4"), 0);
    }

    function test_Move_RevertsOnOpenOrMissingGame() public {
        vm.prank(alice);
        uint256 open = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.makeMove(open, sq("e2"), sq("e4"), 0);
        vm.prank(alice);
        vm.expectRevert(OnchainChess.GameNotFound.selector);
        chess.makeMove(99, sq("e2"), sq("e4"), 0);
    }

    function test_Move_RevertsOnInvalidSquare() public {
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidSquare.selector);
        chess.makeMove(id, 64, sq("e4"), 0);
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidSquare.selector);
        chess.makeMove(id, sq("e2"), 64, 0);
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidSquare.selector);
        chess.makeMove(id, 255, 255, 0);
    }

    function test_Move_RevertsOnIllegalGeometry() public {
        // pawn triple, pawn sideways, pawn backward-ish
        _expectIllegal("e2", "e5");
        _expectIllegal("e2", "d2");
        // blocked sliders
        _expectIllegal("c1", "e3"); // bishop blocked by d2
        _expectIllegal("a1", "a3"); // rook blocked by a2
        _expectIllegal("d1", "d3"); // queen blocked by d2
        // knight bad shape, king 2 squares (no castling)
        _expectIllegal("b1", "b3");
        _expectIllegal("e1", "g1");
        // own piece capture
        _expectIllegal("d1", "d2");
        _expectIllegal("b1", "d2");
        // same square, empty origin, enemy piece
        _expectIllegal("e2", "e2");
        _expectIllegal("e4", "e5");
        _expectIllegal("e7", "e5");
        // pawn diagonal onto empty square
        _expectIllegal("e2", "d3");
    }

    function test_Move_IllegalMoveLeavesStateUnchanged() public {
        OnchainChess.Game memory before = game(id);
        _expectIllegal("e2", "e5");
        OnchainChess.Game memory after_ = game(id);
        assertEq(after_.board, before.board);
        assertEq(after_.moveCount, 0);
        assertTrue(after_.whiteToMove);
    }

    function test_Move_PawnDoubleStepRevertsAfterPawnHasMoved() public {
        wm(id, "e2", "e3");
        bm(id, "a7", "a6");
        _expectIllegal("e3", "e5");
        wm(id, "e3", "e4");
    }

    // ---------- promotion ----------

    /// @dev White pawn reaches b7 after capturing on b7; returns with white to move.
    function _whitePawnOnB7() internal {
        wm(id, "a2", "a4");
        bm(id, "h7", "h6");
        wm(id, "a4", "a5");
        bm(id, "h6", "h5");
        wm(id, "a5", "a6");
        bm(id, "h5", "h4");
        wm(id, "a6", "b7"); // captures pawn
        bm(id, "h4", "h3");
    }

    function test_Promotion_RequiredOnFinalRank() public {
        _whitePawnOnB7();
        assertEq(chess.legalTargetsFor(id, sq("b7")), bits("a8 c8")); // b8 blocked by knight
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidPromotion.selector);
        chess.makeMove(id, sq("b7"), sq("a8"), 0);
    }

    function test_Promotion_InvalidTypesRejected() public {
        _whitePawnOnB7();
        uint8[5] memory bad = [1, 6, 7, 8, 255];
        for (uint256 i; i < bad.length; ++i) {
            vm.prank(alice);
            vm.expectRevert(OnchainChess.InvalidPromotion.selector);
            chess.makeMove(id, sq("b7"), sq("a8"), bad[i]);
        }
    }

    function test_Promotion_AllValidTypesPlaceCorrectPiece() public {
        _whitePawnOnB7();
        uint256 snap = vm.snapshotState();
        for (uint8 t = 2; t <= 5; ++t) {
            vm.expectEmit(true, true, false, true, address(chess));
            emit OnchainChess.MoveMade(id, alice, sq("b7"), sq("a8"), WP, BR, t, 9);
            wp(id, "b7", "a8", t);
            assertEq(pieceAt(game(id).board, sq("a8")), t);
            assertEq(pieceAt(game(id).board, sq("b7")), 0);
            vm.revertToState(snap);
            snap = vm.snapshotState();
        }
    }

    function test_Promotion_CaptureOnC8() public {
        _whitePawnOnB7();
        wp(id, "b7", "c8", WQ);
        assertEq(pieceAt(game(id).board, sq("c8")), WQ);
    }

    function test_Promotion_BlackPromotesToBlackPiece() public {
        wm(id, "h2", "h3");
        bm(id, "a7", "a5");
        wm(id, "h3", "h4");
        bm(id, "a5", "a4");
        wm(id, "h4", "h5");
        bm(id, "a4", "a3");
        wm(id, "h5", "h6");
        bm(id, "a3", "b2"); // capture
        wm(id, "h6", "g7"); // capture
        assertEq(chess.legalTargetsFor(id, sq("b2")), bits("a1 c1"));
        bp(id, "b2", "a1", WQ); // promotion arg is a piece TYPE (5 = queen)
        assertEq(pieceAt(game(id).board, sq("a1")), BQ);
    }

    function test_Promotion_BlackRequiresPromotionToo() public {
        wm(id, "h2", "h3");
        bm(id, "a7", "a5");
        wm(id, "h3", "h4");
        bm(id, "a5", "a4");
        wm(id, "h4", "h5");
        bm(id, "a4", "a3");
        wm(id, "h5", "h6");
        bm(id, "a3", "b2");
        wm(id, "h6", "g7");
        vm.prank(bob);
        vm.expectRevert(OnchainChess.InvalidPromotion.selector);
        chess.makeMove(id, sq("b2"), sq("a1"), 0);
    }

    function test_Promotion_ForbiddenOnNonPromotionMoves() public {
        // pawn move not reaching last rank
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidPromotion.selector);
        chess.makeMove(id, sq("e2"), sq("e4"), 5);
        // non-pawn move
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidPromotion.selector);
        chess.makeMove(id, sq("b1"), sq("c3"), 2);
    }

    function test_Promotion_IllegalGeometryStillReportsIllegalMove() public {
        vm.prank(alice);
        vm.expectRevert(OnchainChess.IllegalMove.selector);
        chess.makeMove(id, sq("e2"), sq("e5"), 5);
    }

    // ---------- king capture / full game ----------

    function _foolsMateSetup() internal {
        wm(id, "f2", "f3");
        bm(id, "e7", "e5");
        wm(id, "g2", "g4");
        bm(id, "d8", "h4"); // "mate" - but game continues until king captured
        wm(id, "a2", "a3"); // white ignores it
    }

    function test_FullGame_KingCapturePaysWinnerDoubleWager() public {
        _foolsMateSetup();
        // game is still active: no checkmate detection
        assertEq(uint8(game(id).status), uint8(OnchainChess.Status.Active));
        uint256 bobBefore = usdc.balanceOf(bob);

        vm.expectEmit(true, true, false, true, address(chess));
        emit OnchainChess.MoveMade(id, bob, sq("h4"), sq("e1"), BQ, WK, 0, 6);
        vm.expectEmit(true, true, false, true, address(chess));
        emit OnchainChess.GameEnded(id, bob, OnchainChess.EndReason.KingCaptured);
        bm(id, "h4", "e1");

        OnchainChess.Game memory g = game(id);
        assertEq(uint8(g.status), uint8(OnchainChess.Status.Finished));
        assertEq(uint8(g.endReason), uint8(OnchainChess.EndReason.KingCaptured));
        assertEq(g.winner, bob);
        assertEq(usdc.balanceOf(bob), bobBefore + 2 * uint256(WAGER));
        assertEq(usdc.balanceOf(bob), FUNDS + WAGER);
        assertEq(usdc.balanceOf(alice), FUNDS - WAGER);
        assertEq(usdc.balanceOf(address(chess)), 0);
    }

    function test_FullGame_NoMovesAfterFinish() public {
        _foolsMateSetup();
        bm(id, "h4", "e1");
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.makeMove(id, sq("a3"), sq("a4"), 0);
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.resign(id);
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.claimTimeout(id);
    }

    function test_FullGame_WhiteCanWinByKingCaptureToo() public {
        wm(id, "e2", "e4");
        bm(id, "f7", "f6");
        wm(id, "d1", "h5");
        bm(id, "a7", "a6");
        wm(id, "h5", "e8"); // path g6? h5->e8 diag: g6, f7 (empty after f7f6) -> captures king e8
        assertEq(uint8(game(id).status), uint8(OnchainChess.Status.Finished));
        assertEq(game(id).winner, alice);
        assertEq(usdc.balanceOf(alice), FUNDS + WAGER);
    }

    function test_FullGame_KingCaptureInFreeGameMovesNoTokens() public {
        vm.prank(carol);
        uint256 fid = chess.createGame(0, TIMEOUT, true, address(0));
        vm.prank(dave);
        chess.joinGame(fid);
        vm.startPrank(carol);
        chess.makeMove(fid, sq("e2"), sq("e4"), 0);
        vm.stopPrank();
        vm.prank(dave);
        chess.makeMove(fid, sq("f7"), sq("f6"), 0);
        vm.prank(carol);
        chess.makeMove(fid, sq("d1"), sq("h5"), 0);
        vm.prank(dave);
        chess.makeMove(fid, sq("a7"), sq("a6"), 0);
        uint256 bal = usdc.balanceOf(carol);
        vm.prank(carol);
        chess.makeMove(fid, sq("h5"), sq("e8"), 0);
        assertEq(game(fid).winner, carol);
        assertEq(usdc.balanceOf(carol), bal);
    }

    // ---------- helpers ----------

    function _expectIllegal(string memory f, string memory t) internal {
        vm.prank(alice);
        vm.expectRevert(OnchainChess.IllegalMove.selector);
        chess.makeMove(id, sq(f), sq(t), 0);
    }
}
