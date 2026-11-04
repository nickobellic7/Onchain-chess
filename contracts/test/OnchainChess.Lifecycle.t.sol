// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OnchainChess} from "../OnchainChess.sol";
import {OnchainChessTestBase} from "./OnchainChess.Base.t.sol";

/// @dev constructor, createGame, joinGame, cancelGame.
contract OnchainChessLifecycleTest is OnchainChessTestBase {
    // ---------- constructor ----------

    function test_Constructor_StoresToken() public view {
        assertEq(address(chess.usdc()), address(usdc));
        assertEq(chess.gameCount(), 0);
    }

    function test_Constructor_RevertsOnZeroToken() public {
        vm.expectRevert(OnchainChess.ZeroAddress.selector);
        new OnchainChess(IERC20(address(0)));
    }

    // ---------- createGame ----------

    function test_Create_AsWhiteEscrowsWagerAndStoresState() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, true, address(0));
        assertEq(id, 1);
        assertEq(chess.gameCount(), 1);

        OnchainChess.Game memory g = game(id);
        assertEq(g.white, alice);
        assertEq(g.black, address(0));
        assertEq(g.invited, address(0));
        assertEq(g.wager, WAGER);
        assertEq(g.moveTimeout, TIMEOUT);
        assertEq(uint8(g.status), uint8(OnchainChess.Status.Open));
        assertEq(uint8(g.endReason), uint8(OnchainChess.EndReason.None));
        assertTrue(g.whiteToMove);
        assertEq(g.moveCount, 0);
        assertEq(g.drawOfferedBy, 0);
        assertEq(g.winner, address(0));
        assertEq(g.board, initialBoard());
        assertEq(usdc.balanceOf(address(chess)), WAGER);
        assertEq(usdc.balanceOf(alice), FUNDS - WAGER);
    }

    function test_Create_AsBlackAssignsBlackSlot() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, false, address(0));
        OnchainChess.Game memory g = game(id);
        assertEq(g.black, alice);
        assertEq(g.white, address(0));
    }

    function test_Create_IdsIncrement() public {
        vm.startPrank(alice);
        assertEq(chess.createGame(0, TIMEOUT, true, address(0)), 1);
        assertEq(chess.createGame(0, TIMEOUT, true, address(0)), 2);
        vm.stopPrank();
        assertEq(chess.gameCount(), 2);
    }

    function test_Create_FreeGameMovesNoTokensAndNeedsNoAllowance() public {
        address eve = makeAddr("eve"); // no tokens, no allowance
        vm.prank(eve);
        uint256 id = chess.createGame(0, TIMEOUT, true, address(0));
        assertEq(game(id).wager, 0);
        assertEq(usdc.balanceOf(address(chess)), 0);
    }

    function test_Create_EmitsGameCreated() public {
        vm.expectEmit(true, true, false, true, address(chess));
        emit OnchainChess.GameCreated(1, alice, WAGER, TIMEOUT, false, carol);
        vm.prank(alice);
        chess.createGame(WAGER, TIMEOUT, false, carol);
    }

    function test_Create_TimeoutBoundariesAccepted() public {
        vm.startPrank(alice);
        chess.createGame(0, 60, true, address(0));
        chess.createGame(0, 30 days, true, address(0));
        vm.stopPrank();
        assertEq(game(1).moveTimeout, 60);
        assertEq(game(2).moveTimeout, 30 days);
    }

    function test_Create_RevertsOnTimeoutTooShort() public {
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidMoveTimeout.selector);
        chess.createGame(WAGER, 59, true, address(0));
    }

    function test_Create_RevertsOnTimeoutTooLong() public {
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidMoveTimeout.selector);
        chess.createGame(WAGER, uint32(30 days) + 1, true, address(0));
    }

    function test_Create_RevertsOnSelfInvite() public {
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidInvitation.selector);
        chess.createGame(WAGER, TIMEOUT, true, alice);
    }

    function test_Create_RevertsWithoutAllowance() public {
        address eve = makeAddr("eve");
        usdc.mint(eve, FUNDS);
        vm.prank(eve);
        vm.expectRevert();
        chess.createGame(WAGER, TIMEOUT, true, address(0));
    }

    function test_Create_RevertsWithoutBalance() public {
        address eve = makeAddr("eve");
        vm.startPrank(eve);
        usdc.approve(address(chess), type(uint256).max);
        vm.expectRevert();
        chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.stopPrank();
    }

    // ---------- joinGame ----------

    function test_Join_ActivatesGameAndEscrowsMatchingWager() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, true, address(0));
        skip(5);
        vm.prank(bob);
        chess.joinGame(id);

        OnchainChess.Game memory g = game(id);
        assertEq(g.black, bob);
        assertEq(g.white, alice);
        assertEq(uint8(g.status), uint8(OnchainChess.Status.Active));
        assertEq(g.lastMoveAt, uint40(block.timestamp));
        assertTrue(g.whiteToMove);
        assertEq(usdc.balanceOf(address(chess)), 2 * uint256(WAGER));
        assertEq(usdc.balanceOf(bob), FUNDS - WAGER);
    }

    function test_Join_JoinerTakesWhiteWhenCreatorIsBlackAndMovesFirst() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, false, address(0));
        vm.prank(bob);
        chess.joinGame(id);
        OnchainChess.Game memory g = game(id);
        assertEq(g.white, bob);
        assertEq(g.black, alice);
        assertTrue(g.whiteToMove);

        // alice (black) cannot move first; bob (white) can
        vm.prank(alice);
        vm.expectRevert(OnchainChess.NotYourTurn.selector);
        chess.makeMove(id, sq("e7"), sq("e5"), 0);
        vm.prank(bob);
        chess.makeMove(id, sq("e2"), sq("e4"), 0);
    }

    function test_Join_EmitsGameJoined() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.expectEmit(true, true, false, false, address(chess));
        emit OnchainChess.GameJoined(id, bob);
        vm.prank(bob);
        chess.joinGame(id);
    }

    function test_Join_FreeGameNeedsNoAllowance() public {
        vm.prank(alice);
        uint256 id = chess.createGame(0, TIMEOUT, true, address(0));
        address eve = makeAddr("eve");
        vm.prank(eve);
        chess.joinGame(id);
        assertEq(uint8(game(id).status), uint8(OnchainChess.Status.Active));
    }

    function test_Join_InvitedOnly() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, true, bob);
        vm.prank(carol);
        vm.expectRevert(OnchainChess.NotInvited.selector);
        chess.joinGame(id);
        vm.prank(bob);
        chess.joinGame(id);
        assertEq(game(id).black, bob);
        assertEq(game(id).invited, bob);
    }

    function test_Join_PublicGameAnyoneMayJoin() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.prank(dave);
        chess.joinGame(id);
        assertEq(game(id).black, dave);
    }

    function test_Join_RevertsOnOwnGame() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.prank(alice);
        vm.expectRevert(OnchainChess.CannotJoinOwnGame.selector);
        chess.joinGame(id);

        vm.prank(alice);
        uint256 id2 = chess.createGame(WAGER, TIMEOUT, false, address(0));
        vm.prank(alice);
        vm.expectRevert(OnchainChess.CannotJoinOwnGame.selector);
        chess.joinGame(id2);
    }

    function test_Join_RevertsOnMissingGame() public {
        vm.prank(bob);
        vm.expectRevert(OnchainChess.GameNotFound.selector);
        chess.joinGame(1);
        vm.prank(bob);
        vm.expectRevert(OnchainChess.GameNotFound.selector);
        chess.joinGame(0);
    }

    function test_Join_RevertsWhenAlreadyActive() public {
        uint256 id = newGame();
        vm.prank(carol);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.joinGame(id);
    }

    function test_Join_RevertsWhenCancelled() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.prank(alice);
        chess.cancelGame(id);
        vm.prank(bob);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.joinGame(id);
    }

    function test_Join_RevertsWithoutAllowance() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, true, address(0));
        address eve = makeAddr("eve");
        usdc.mint(eve, FUNDS);
        vm.prank(eve);
        vm.expectRevert();
        chess.joinGame(id);
        // failed join leaves the game open
        assertEq(uint8(game(id).status), uint8(OnchainChess.Status.Open));
    }

    // ---------- cancelGame ----------

    function test_Cancel_RefundsCreatorAndMarksCancelled() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.prank(alice);
        chess.cancelGame(id);

        OnchainChess.Game memory g = game(id);
        assertEq(uint8(g.status), uint8(OnchainChess.Status.Cancelled));
        assertEq(uint8(g.endReason), uint8(OnchainChess.EndReason.Cancelled));
        assertEq(g.winner, address(0));
        assertEq(usdc.balanceOf(alice), FUNDS);
        assertEq(usdc.balanceOf(address(chess)), 0);
    }

    function test_Cancel_BlackCreatorIsRefunded() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, false, address(0));
        vm.prank(alice);
        chess.cancelGame(id);
        assertEq(usdc.balanceOf(alice), FUNDS);
    }

    function test_Cancel_EmitsGameEnded() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.expectEmit(true, true, false, true, address(chess));
        emit OnchainChess.GameEnded(id, address(0), OnchainChess.EndReason.Cancelled);
        vm.prank(alice);
        chess.cancelGame(id);
    }

    function test_Cancel_RevertsForNonCreator() public {
        vm.prank(alice);
        uint256 id = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.prank(bob);
        vm.expectRevert(OnchainChess.NotCreator.selector);
        chess.cancelGame(id);

        vm.prank(alice);
        uint256 id2 = chess.createGame(WAGER, TIMEOUT, false, address(0));
        vm.prank(bob);
        vm.expectRevert(OnchainChess.NotCreator.selector);
        chess.cancelGame(id2);
    }

    function test_Cancel_RevertsOnceJoinedOrAlreadyCancelled() public {
        uint256 id = newGame();
        vm.prank(alice);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.cancelGame(id);

        vm.prank(alice);
        uint256 id2 = chess.createGame(WAGER, TIMEOUT, true, address(0));
        vm.startPrank(alice);
        chess.cancelGame(id2);
        vm.expectRevert(OnchainChess.InvalidStatus.selector);
        chess.cancelGame(id2);
        vm.stopPrank();
    }

    function test_Cancel_RevertsOnMissingGame() public {
        vm.prank(alice);
        vm.expectRevert(OnchainChess.GameNotFound.selector);
        chess.cancelGame(7);
    }

    function test_GetGame_RevertsOnMissingGame() public {
        vm.expectRevert(OnchainChess.GameNotFound.selector);
        chess.getGame(1);
    }
}
