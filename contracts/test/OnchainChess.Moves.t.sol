// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OnchainChess} from "../OnchainChess.sol";
import {OnchainChessTestBase} from "./OnchainChess.Base.t.sol";

/// @dev legalTargets geometry from the start position and custom boards.
contract OnchainChessMovesTest is OnchainChessTestBase {
    // ---------- start position ----------

    function test_Start_Board_MatchesIndependentLayout() public {
        uint256 id = newGame();
        assertEq(game(id).board, initialBoard());
    }

    function test_Start_PawnsHaveSingleAndDoubleStep() public view {
        uint256 b0 = initialBoard();
        for (uint8 f; f < 8; ++f) {
            assertEq(chess.legalTargets(b0, true, 8 + f), (uint64(1) << (16 + f)) | (uint64(1) << (24 + f)));
            assertEq(chess.legalTargets(b0, false, 48 + f), (uint64(1) << (40 + f)) | (uint64(1) << (32 + f)));
        }
    }

    function test_Start_Knights() public view {
        uint256 b0 = initialBoard();
        assertEq(targets(b0, true, "b1"), bits("a3 c3"));
        assertEq(targets(b0, true, "g1"), bits("f3 h3"));
        assertEq(targets(b0, false, "b8"), bits("a6 c6"));
        assertEq(targets(b0, false, "g8"), bits("f6 h6"));
    }

    function test_Start_BishopsRooksQueensKingsAreBoxedIn() public view {
        uint256 b0 = initialBoard();
        string[8] memory back = ["a", "b", "c", "d", "e", "f", "g", "h"];
        for (uint256 i; i < 8; ++i) {
            if (i == 1 || i == 6) continue; // knights
            assertEq(targets(b0, true, string.concat(back[i], "1")), 0);
            assertEq(targets(b0, false, string.concat(back[i], "8")), 0);
        }
    }

    function test_Start_WrongColorOrEmptyYieldsZero() public view {
        uint256 b0 = initialBoard();
        assertEq(targets(b0, false, "e2"), 0); // white pawn, black to move
        assertEq(targets(b0, true, "e7"), 0); // black pawn, white to move
        assertEq(targets(b0, true, "e4"), 0); // empty
    }

    function test_LegalTargets_RevertsOnInvalidFrom() public {
        uint256 b0 = initialBoard();
        vm.expectRevert(OnchainChess.InvalidSquare.selector);
        chess.legalTargets(b0, true, 64);
        vm.expectRevert(OnchainChess.InvalidSquare.selector);
        chess.legalTargets(b0, true, 255);
    }

    function test_LegalTargetsFor_UsesGameBoardAndTurn() public {
        uint256 id = newGame();
        assertEq(chess.legalTargetsFor(id, sq("e2")), bits("e3 e4"));
        assertEq(chess.legalTargetsFor(id, sq("e7")), 0); // white to move
        wm(id, "e2", "e4");
        assertEq(chess.legalTargetsFor(id, sq("e7")), bits("e6 e5"));
        assertEq(chess.legalTargetsFor(id, sq("e4")), 0); // white piece, black to move
    }

    function test_LegalTargetsFor_RevertsOnMissingGame() public {
        vm.expectRevert(OnchainChess.GameNotFound.selector);
        chess.legalTargetsFor(1, 0);
    }

    // ---------- pawns ----------

    function test_Pawn_BlockedByPieceInFrontCannotMoveOrDouble() public view {
        uint256 bd = put(put(0, "e2", WP), "e3", BN);
        assertEq(targets(bd, true, "e2"), 0);
        bd = put(put(0, "e2", WP), "e3", WN); // own piece
        assertEq(targets(bd, true, "e2"), 0);
    }

    function test_Pawn_DoubleStepBlockedOnSecondSquare() public view {
        uint256 bd = put(put(0, "e2", WP), "e4", BN);
        assertEq(targets(bd, true, "e2"), bits("e3"));
        bd = put(put(0, "e2", WP), "e4", WN);
        assertEq(targets(bd, true, "e2"), bits("e3"));
    }

    function test_Pawn_CapturesDiagonallyOnlyEnemies() public view {
        uint256 bd = put(put(put(0, "e2", WP), "d3", BN), "f3", BP);
        assertEq(targets(bd, true, "e2"), bits("e3 e4 d3 f3"));
        bd = put(put(put(0, "e2", WP), "d3", WN), "f3", BP); // own piece on d3
        assertEq(targets(bd, true, "e2"), bits("e3 e4 f3"));
    }

    function test_Pawn_CannotCaptureForwardOrMoveBackward() public view {
        uint256 bd = put(put(0, "e4", WP), "e5", BP);
        assertEq(targets(bd, true, "e4"), 0);
        bd = put(0, "e4", WP);
        assertEq(targets(bd, true, "e4"), bits("e5")); // no double step off rank 2, no backward
    }

    function test_Pawn_NoDoubleStepOffStartRank() public view {
        assertEq(targets(put(0, "e3", WP), true, "e3"), bits("e4"));
        assertEq(targets(put(0, "e6", BP), false, "e6"), bits("e5"));
        // black pawn on rank 2 is not on its start rank
        assertEq(targets(put(0, "e2", BP), false, "e2"), bits("e1"));
    }

    function test_Pawn_EdgeFilesDoNotWrap() public view {
        uint256 bd = put(put(put(0, "a2", WP), "b3", BN), "h3", BN);
        assertEq(targets(bd, true, "a2"), bits("a3 a4 b3"));
        bd = put(put(put(0, "h2", WP), "g3", BN), "a3", BN);
        assertEq(targets(bd, true, "h2"), bits("h3 h4 g3"));
    }

    function test_Pawn_Black() public view {
        uint256 bd = put(put(put(0, "e7", BP), "d6", WN), "f6", WP);
        assertEq(targets(bd, false, "e7"), bits("e6 e5 d6 f6"));
        bd = put(put(0, "e7", BP), "e6", WN);
        assertEq(targets(bd, false, "e7"), 0);
        bd = put(put(0, "e7", BP), "e5", WN);
        assertEq(targets(bd, false, "e7"), bits("e6"));
    }

    function test_Pawn_FinalRankTargetsIncluded() public view {
        uint256 bd = put(put(put(0, "e7", WP), "d8", BR), "f8", BN);
        assertEq(targets(bd, true, "e7"), bits("e8 d8 f8"));
        assertEq(targets(put(0, "b2", BP), false, "b2"), bits("b1"));
    }

    // ---------- knights ----------

    function test_Knight_CenterAndCorners() public view {
        assertEq(targets(put(0, "d4", WN), true, "d4"), bits("b3 b5 c2 c6 e2 e6 f3 f5"));
        assertEq(targets(put(0, "a1", WN), true, "a1"), bits("b3 c2"));
        assertEq(targets(put(0, "h1", WN), true, "h1"), bits("f2 g3"));
        assertEq(targets(put(0, "h8", BN), false, "h8"), bits("f7 g6"));
    }

    function test_Knight_JumpsOverPiecesAndRespectsOccupants() public view {
        uint256 bd = put(0, "d4", WN);
        // surround with pieces: no effect on jumps
        bd = put(put(put(put(bd, "d5", WP), "d3", WP), "c4", BP), "e4", BP);
        assertEq(targets(bd, true, "d4"), bits("b3 b5 c2 c6 e2 e6 f3 f5"));
        // own on b3 excluded, enemy on c6 included
        bd = put(put(bd, "b3", WB), "c6", BB);
        assertEq(targets(bd, true, "d4"), bits("b5 c2 c6 e2 e6 f3 f5"));
    }

    // ---------- bishop ----------

    function test_Bishop_OpenBoard() public view {
        assertEq(targets(put(0, "d4", WB), true, "d4"), bits("a1 b2 c3 e5 f6 g7 h8 a7 b6 c5 e3 f2 g1"));
    }

    function test_Bishop_BlockedByOwnAndEnemy() public view {
        uint256 bd = put(put(0, "d4", WB), "f6", WP); // own blocker
        assertEq(targets(bd, true, "d4"), bits("a1 b2 c3 e5 a7 b6 c5 e3 f2 g1"));
        bd = put(put(0, "d4", WB), "f6", BP); // enemy blocker: capture, not beyond
        assertEq(targets(bd, true, "d4"), bits("a1 b2 c3 e5 f6 a7 b6 c5 e3 f2 g1"));
        bd = put(put(put(0, "d4", WB), "c3", WP), "e3", BP);
        assertEq(targets(bd, true, "d4"), bits("e5 f6 g7 h8 a7 b6 c5 e3"));
    }

    // ---------- rook ----------

    function test_Rook_OpenBoard() public view {
        assertEq(targets(put(0, "d4", WR), true, "d4"), bits("d1 d2 d3 d5 d6 d7 d8 a4 b4 c4 e4 f4 g4 h4"));
    }

    function test_Rook_BlockedByOwnAndEnemy() public view {
        uint256 bd = put(put(0, "d4", WR), "d6", WP);
        assertEq(targets(bd, true, "d4"), bits("d1 d2 d3 d5 a4 b4 c4 e4 f4 g4 h4"));
        bd = put(put(0, "d4", WR), "d6", BP);
        assertEq(targets(bd, true, "d4"), bits("d1 d2 d3 d5 d6 a4 b4 c4 e4 f4 g4 h4"));
        bd = put(put(0, "d4", WR), "b4", BN);
        assertEq(targets(bd, true, "d4"), bits("d1 d2 d3 d5 d6 d7 d8 b4 c4 e4 f4 g4 h4"));
    }

    function test_Rook_NoWrapAcrossRanks() public view {
        // rook h4 must not reach a5 (index wraps) or other files via wrap
        assertEq(targets(put(0, "h4", WR), true, "h4"), bits("h1 h2 h3 h5 h6 h7 h8 a4 b4 c4 d4 e4 f4 g4"));
    }

    // ---------- queen ----------

    function test_Queen_OpenBoard() public view {
        uint64 m = targets(put(0, "d4", WQ), true, "d4");
        assertEq(
            m,
            bits("d1 d2 d3 d5 d6 d7 d8 a4 b4 c4 e4 f4 g4 h4") | bits("a1 b2 c3 e5 f6 g7 h8 a7 b6 c5 e3 f2 g1")
        );
    }

    function test_Queen_BlockingAndNoKnightJumps() public view {
        uint256 bd = put(put(put(0, "d4", WQ), "d6", WP), "f6", BP);
        bd = put(bd, "b4", WP);
        uint64 expected = bits("d1 d2 d3 d5 c4 e4 f4 g4 h4") | bits("a1 b2 c3 e5 f6 a7 b6 c5 e3 f2 g1");
        assertEq(targets(bd, true, "d4"), expected);
        assertEq(targets(bd, true, "d4") & bits("e6 c6 b5 b3 f5 f3 c2 e2"), 0);
    }

    function test_Queen_BlackSymmetry() public view {
        uint256 bd = put(put(0, "d4", BQ), "d6", WP);
        assertEq(
            targets(bd, false, "d4"),
            bits("d1 d2 d3 d5 d6 a4 b4 c4 e4 f4 g4 h4") | bits("a1 b2 c3 e5 f6 g7 h8 a7 b6 c5 e3 f2 g1")
        );
    }

    // ---------- king ----------

    function test_King_CenterAndCorner() public view {
        assertEq(targets(put(0, "d4", WK), true, "d4"), bits("c3 c4 c5 d3 d5 e3 e4 e5"));
        assertEq(targets(put(0, "a1", WK), true, "a1"), bits("a2 b1 b2"));
        assertEq(targets(put(0, "h8", BK), false, "h8"), bits("g8 g7 h7"));
    }

    function test_King_OwnExcludedEnemyIncluded() public view {
        uint256 bd = put(put(put(0, "d4", WK), "d5", WP), "e5", BP);
        assertEq(targets(bd, true, "d4"), bits("c3 c4 c5 d3 e3 e4 e5"));
    }

    function test_King_NoCastling() public view {
        uint256 bd = put(put(put(0, "e1", WK), "h1", WR), "a1", WR);
        assertEq(targets(bd, true, "e1"), bits("d1 d2 e2 f1 f2"));
    }

    function test_King_MayMoveIntoAttackedSquare() public view {
        // black rook on a2 attacks the whole 2nd rank; king may still step there (no check rule)
        uint256 bd = put(put(0, "e1", WK), "a2", BR);
        assertEq(targets(bd, true, "e1"), bits("d1 d2 e2 f1 f2"));
    }

    // ---------- malformed nibbles ----------

    function test_InvalidNibbles_NeverSourceOrTarget() public view {
        assertEq(targets(put(0, "d4", 7), true, "d4"), 0);
        assertEq(targets(put(0, "d4", 15), false, "d4"), 0);
        assertEq(targets(put(0, "d4", 8), false, "d4"), 0);
        uint256 bd = put(put(put(put(0, "a1", WR), "a4", 7), "c1", 15), "e1", 8);
        assertEq(targets(bd, true, "a1"), bits("a2 a3 b1"));
    }
}
