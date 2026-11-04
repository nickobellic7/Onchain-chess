// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OnchainChess} from "../OnchainChess.sol";
import {OnchainChessTestBase} from "./OnchainChess.Base.t.sol";

/// @dev resign, draws, timeouts, deferred payouts and withdrawOwed.
contract OnchainChessSettleTest is OnchainChessTestBase {
    uint256 internal id;
    uint256 internal t0;

    function setUp() public override {
        super.setUp();
        id = newGame();
        t0 = block.timestamp;
    }

    // ---------- resign ----------

    function test_Resign_WhiteResignsBlackWinsPot() public {
        vm.expectEmit(true, true, false, true, address(chess));
        emit OnchainChess.GameEnded(id, bob, OnchainChess.EndReason.Resigned);
        vm.prank(alice);
        chess.resign(id);

        OnchainChess.Game memory g = game(id);
        assertEq(uint8(g.status), uint8(OnchainChess.Status.Finished));
        assertEq(uint8(g.endReason), uint8(OnchainChess.EndReason.Resigned));
        assertEq(g.winner, bob);
        assertEq(usdc.balanceOf(bob), FUNDS + WAGER);
        assertEq(usdc.balanceOf(alice), FUNDS - WAGER);
        assertEq(usdc.balanceOf(address(chess)), 0);
    }

    function test_Resign_BlackResignsWhiteWins_EvenOutOfTurn() public {
        // it is white's turn; black may still resign
        vm.prank(bob);
        chess.resign(id);
        assertEq(game(id).winner, alice);
        assertEq(usdc.balanceOf(alice), FUNDS + WAGER);
    }

    function test_Resign_RevertsForNonPlayer() public {
        vm.prank(carol);
        vm.expectRevert(OnchainChess.NotPlayer.selector);
        chess.resign(id);
    }

    function test_Resign_RevertsOnOpenFinishedOrMissing() public {
        vm.prank(alice);
        uint256 open = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.resign(open);

        vm.prank(alice);
        chess.resign(id);
        vm.prank(bob);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.resign(id);

        vm.prank(alice);
        vm.expectRevert(OnchainChess.GameNotFound.selector);
        chess.resign(123);
    }

    function test_Resign_FreeGamePaysNothing() public {
        vm.prank(carol);
        uint256 fid = chess.createGame(0, TIMEOUT, true, address(0));
        vm.prank(dave);
        chess.joinGame(fid);
        vm.prank(carol);
        chess.resign(fid);
        assertEq(game(fid).winner, dave);
        assertEq(usdc.balanceOf(dave), FUNDS);
        assertEq(usdc.balanceOf(carol), FUNDS);
    }

    // ---------- draws ----------

    function test_Draw_OfferEmitsAndRecordsSide() public {
        vm.expectEmit(true, true, false, false, address(chess));
        emit OnchainChess.DrawOffered(id, bob);
        vm.prank(bob); // offering out of turn is allowed
        chess.offerDraw(id);
        assertEq(game(id).drawOfferedBy, 2);

        vm.prank(alice);
        chess.offerDraw(id); // replaces
        assertEq(game(id).drawOfferedBy, 1);
    }

    function test_Draw_AcceptRefundsBothWagers() public {
        vm.prank(alice);
        chess.offerDraw(id);

        vm.expectEmit(true, true, false, true, address(chess));
        emit OnchainChess.GameEnded(id, address(0), OnchainChess.EndReason.DrawAgreed);
        vm.prank(bob);
        chess.acceptDraw(id);

        OnchainChess.Game memory g = game(id);
        assertEq(uint8(g.status), uint8(OnchainChess.Status.Finished));
        assertEq(uint8(g.endReason), uint8(OnchainChess.EndReason.DrawAgreed));
        assertEq(g.winner, address(0));
        assertEq(g.drawOfferedBy, 0);
        assertEq(usdc.balanceOf(alice), FUNDS);
        assertEq(usdc.balanceOf(bob), FUNDS);
        assertEq(usdc.balanceOf(address(chess)), 0);
    }

    function test_Draw_BlackOffersWhiteAccepts() public {
        vm.prank(bob);
        chess.offerDraw(id);
        vm.prank(alice);
        chess.acceptDraw(id);
        assertEq(uint8(game(id).endReason), uint8(OnchainChess.EndReason.DrawAgreed));
    }

    function test_Draw_CannotAcceptOwnOffer() public {
        vm.prank(alice);
        chess.offerDraw(id);
        vm.prank(alice);
        vm.expectRevert(OnchainChess.CannotAcceptOwnDraw.selector);
        chess.acceptDraw(id);
    }

    function test_Draw_ReplacedOfferCanOnlyBeAcceptedByNewOfferee() public {
        vm.prank(alice);
        chess.offerDraw(id);
        vm.prank(bob);
        chess.offerDraw(id); // bob now the offerer
        vm.prank(bob);
        vm.expectRevert(OnchainChess.CannotAcceptOwnDraw.selector);
        chess.acceptDraw(id);
        vm.prank(alice);
        chess.acceptDraw(id);
    }

    function test_Draw_AcceptWithoutOfferReverts() public {
        vm.prank(bob);
        vm.expectRevert(OnchainChess.NoDrawOffer.selector);
        chess.acceptDraw(id);
    }

    function test_Draw_OpponentMoveDeclinesOffer() public {
        // black offers, white moves (declines): offer cleared and cannot be accepted
        vm.prank(bob);
        chess.offerDraw(id);
        wm(id, "e2", "e4");
        assertEq(game(id).drawOfferedBy, 0);
        vm.prank(alice);
        vm.expectRevert(OnchainChess.NoDrawOffer.selector);
        chess.acceptDraw(id);
        vm.prank(bob);
        vm.expectRevert(OnchainChess.NoDrawOffer.selector);
        chess.acceptDraw(id);
    }

    function test_Draw_OffererMovingAlsoClearsOffer() public {
        vm.prank(alice);
        chess.offerDraw(id);
        wm(id, "e2", "e4");
        assertEq(game(id).drawOfferedBy, 0);
    }

    function test_Draw_NonPlayerReverts() public {
        vm.prank(carol);
        vm.expectRevert(OnchainChess.NotPlayer.selector);
        chess.offerDraw(id);
        vm.prank(alice);
        chess.offerDraw(id);
        vm.prank(carol);
        vm.expectRevert(OnchainChess.NotPlayer.selector);
        chess.acceptDraw(id);
    }

    function test_Draw_RevertsOnOpenFinishedOrMissingGame() public {
        vm.prank(alice);
        uint256 open = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.offerDraw(open);
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.acceptDraw(open);

        vm.prank(alice);
        chess.resign(id);
        vm.prank(bob);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.offerDraw(id);

        vm.prank(bob);
        vm.expectRevert(OnchainChess.GameNotFound.selector);
        chess.offerDraw(77);
    }

    // ---------- timeouts ----------

    function test_Timeout_MoveAllowedExactlyAtDeadline() public {
        vm.warp(t0 + TIMEOUT);
        wm(id, "e2", "e4");
        assertEq(game(id).moveCount, 1);
    }

    function test_Timeout_MoveRevertsOneSecondPastDeadline() public {
        vm.warp(t0 + TIMEOUT + 1);
        vm.prank(alice);
        vm.expectRevert(OnchainChess.MoveTimedOut.selector);
        chess.makeMove(id, sq("e2"), sq("e4"), 0);
    }

    function test_Timeout_ClaimRevertsAtDeadlineInclusive() public {
        vm.warp(t0 + TIMEOUT);
        vm.prank(carol);
        vm.expectRevert(OnchainChess.NotTimedOut.selector);
        chess.claimTimeout(id);
    }

    function test_Timeout_ClaimOneSecondAfterAwardsPotToWaitingPlayer() public {
        vm.warp(t0 + TIMEOUT + 1);
        vm.expectEmit(true, true, false, true, address(chess));
        emit OnchainChess.GameEnded(id, bob, OnchainChess.EndReason.Timeout);
        vm.prank(carol); // anyone may claim
        chess.claimTimeout(id);

        OnchainChess.Game memory g = game(id);
        assertEq(uint8(g.status), uint8(OnchainChess.Status.Finished));
        assertEq(uint8(g.endReason), uint8(OnchainChess.EndReason.Timeout));
        assertEq(g.winner, bob); // white was to move and timed out
        assertEq(usdc.balanceOf(bob), FUNDS + WAGER);
        assertEq(usdc.balanceOf(address(chess)), 0);
    }

    function test_Timeout_BlackToMoveTimesOutWhiteWins() public {
        wm(id, "e2", "e4");
        uint256 t1 = block.timestamp;
        vm.warp(t1 + TIMEOUT + 1);
        vm.prank(alice);
        chess.claimTimeout(id);
        assertEq(game(id).winner, alice);
        assertEq(usdc.balanceOf(alice), FUNDS + WAGER);
    }

    function test_Timeout_TimerResetsAfterEachMove() public {
        vm.warp(t0 + TIMEOUT - 1);
        wm(id, "e2", "e4");
        // 2*TIMEOUT-1 after t0 is only TIMEOUT after the move -> not expired
        vm.warp(t0 + 2 * TIMEOUT - 1);
        vm.prank(carol);
        vm.expectRevert(OnchainChess.NotTimedOut.selector);
        chess.claimTimeout(id);
        bm(id, "e7", "e5");
    }

    function test_Timeout_WrongPlayerAfterExpiryStillNotYourTurn() public {
        vm.warp(t0 + TIMEOUT + 1);
        vm.prank(bob);
        vm.expectRevert(OnchainChess.NotYourTurn.selector);
        chess.makeMove(id, sq("e7"), sq("e5"), 0);
    }

    function test_Timeout_ExpiredGameStillAllowsResignAndDraw() public {
        vm.warp(t0 + TIMEOUT + 1);
        vm.prank(alice);
        chess.offerDraw(id);
        vm.prank(bob);
        chess.acceptDraw(id);
        assertEq(uint8(game(id).endReason), uint8(OnchainChess.EndReason.DrawAgreed));
    }

    function test_Timeout_ClaimRevertsOnOpenFinishedMissing() public {
        vm.prank(alice);
        uint256 open = chess.createGame(WAGER, 60, true, address(0));
        vm.warp(block.timestamp + 10 days);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.claimTimeout(open);

        vm.prank(alice);
        chess.resign(id);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.claimTimeout(id);

        vm.expectRevert(OnchainChess.GameNotFound.selector);
        chess.claimTimeout(500);
    }

    // ---------- deferred payouts ----------

    function test_Deferred_BlacklistedWinnerGetsCreditThenWithdraws() public {
        usdc.setBlacklisted(bob, true);

        vm.expectEmit(true, false, false, true, address(chess));
        emit OnchainChess.PayoutDeferred(bob, 2 * uint256(WAGER));
        vm.prank(alice);
        chess.resign(id); // game still completes

        assertEq(uint8(game(id).status), uint8(OnchainChess.Status.Finished));
        assertEq(game(id).winner, bob);
        assertEq(chess.owed(bob), 2 * uint256(WAGER));
        assertEq(usdc.balanceOf(address(chess)), 2 * uint256(WAGER));
        assertEq(usdc.balanceOf(bob), FUNDS - WAGER);

        // still blacklisted: withdraw reverts and credit is preserved
        vm.prank(bob);
        vm.expectRevert();
        chess.withdrawOwed();
        assertEq(chess.owed(bob), 2 * uint256(WAGER));

        usdc.setBlacklisted(bob, false);
        vm.expectEmit(true, false, false, true, address(chess));
        emit OnchainChess.OwedWithdrawn(bob, 2 * uint256(WAGER));
        vm.prank(bob);
        chess.withdrawOwed();

        assertEq(chess.owed(bob), 0);
        assertEq(usdc.balanceOf(bob), FUNDS + WAGER);
        assertEq(usdc.balanceOf(address(chess)), 0);

        vm.prank(bob);
        vm.expectRevert(OnchainChess.NothingOwed.selector);
        chess.withdrawOwed();
    }

    function test_Deferred_DrawPaysHealthySideAndDefersBlacklistedSide() public {
        usdc.setBlacklisted(alice, true);
        vm.prank(alice);
        chess.offerDraw(id);
        vm.prank(bob);
        chess.acceptDraw(id);

        assertEq(usdc.balanceOf(bob), FUNDS);
        assertEq(usdc.balanceOf(alice), FUNDS - WAGER);
        assertEq(chess.owed(alice), WAGER);
        assertEq(chess.owed(bob), 0);
        assertEq(usdc.balanceOf(address(chess)), WAGER);
    }

    function test_Deferred_CancelByBlacklistedCreatorDefersRefund() public {
        vm.prank(carol);
        uint256 cid = chess.createGame(WAGER, TIMEOUT, true, address(0));
        usdc.setBlacklisted(carol, true);
        vm.prank(carol);
        chess.cancelGame(cid);
        assertEq(uint8(game(cid).status), uint8(OnchainChess.Status.Cancelled));
        assertEq(chess.owed(carol), WAGER);
    }

    function test_Deferred_CreditsAccumulateAcrossGames() public {
        usdc.setBlacklisted(bob, true);
        vm.prank(alice);
        chess.resign(id);

        vm.prank(carol);
        uint256 g2 = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.prank(bob);
        chess.joinGame(g2);
        vm.prank(carol);
        chess.resign(g2);

        assertEq(chess.owed(bob), 4 * uint256(WAGER));
        usdc.setBlacklisted(bob, false);
        vm.prank(bob);
        chess.withdrawOwed();
        assertEq(usdc.balanceOf(bob), FUNDS - 2 * uint256(WAGER) + 4 * uint256(WAGER));
    }

    function test_Withdraw_RevertsWithNothingOwed() public {
        vm.prank(carol);
        vm.expectRevert(OnchainChess.NothingOwed.selector);
        chess.withdrawOwed();
    }
}
