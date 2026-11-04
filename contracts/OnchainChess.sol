// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title OnchainChess
 * @notice Fully onchain, trustless 1v1 king-capture chess with optional USDC wagers.
 * @dev SIMPLIFIED RULESET: movement geometry, blocking, turns, pawn double steps,
 * captures and mandatory promotion are enforced. Castling, en passant, check,
 * checkmate detection and stalemate are NOT implemented. Moving into check is
 * allowed; a checkmated player must still lose their king to lose by capture.
 * Capturing the enemy king immediately wins. Draws require both players' agreement;
 * there are no automatic repetition, move-count or insufficient-material draws.
 * Resignation and per-move timeout also award a win. No owner, admin, fees or upgrades.
 *
 * Board encoding: uint256 with 4 bits per square; index = rank * 8 + file,
 * with zero-based ranks/files: a1=0, b1=1, h1=7, a2=8, h8=63.
 * Nibbles: 0 empty; white 1..6 = Pawn, Knight, Bishop, Rook, Queen, King;
 * black = 8 + type (9..14). Bit 3 is the color bit (0 white, 1 black).
 * Nibbles 7, 8 and 15 are invalid and are never produced by this contract.
 *
 * The constructor token is intended to be Arc Testnet USDC (6 decimals); wagers
 * are raw token units, so 1 USDC = 1_000_000. The token address is not hardcoded.
 * Accounting assumes standard, non-rebasing, non-fee-on-transfer USDC behavior.
 * Failed settlement transfers become withdrawable credits instead of blocking
 * game completion. Token-level freezing/blacklisting can delay credit withdrawal.
 */
contract OnchainChess is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Status { None, Open, Active, Finished, Cancelled }
    enum EndReason { None, KingCaptured, Resigned, Timeout, DrawAgreed, Cancelled }

    struct Game {
        address white;
        address black;
        address invited;
        uint128 wager;
        uint32 moveTimeout;
        uint40 lastMoveAt;
        uint16 moveCount;
        Status status;
        EndReason endReason;
        bool whiteToMove;
        uint8 drawOfferedBy; // 0 none, 1 white, 2 black
        address winner; // Zero for a draw or cancellation.
        uint256 board;
    }

    /// @notice ERC-20 used for wagers, supplied at construction.
    IERC20 public immutable usdc;
    mapping(uint256 => Game) internal games;
    /// @notice Number of games created; game IDs start at 1.
    uint256 public gameCount;
    /// @notice Unpaid settlement credits in raw USDC units.
    mapping(address => uint256) public owed;

    // High nibbles are rank 8 then rank 7; low nibbles are rank 2 then rank 1.
    // Queens start on d1/d8 and kings on e1/e8.
    uint256 private constant INITIAL_BOARD =
        (uint256(0xcabedbac99999999) << 192) | uint256(0x1111111142365324);

    error ZeroAddress();
    error GameNotFound();
    error InvalidStatus();
    error InvalidMoveTimeout();
    error InvalidInvitation();
    error NotCreator();
    error CannotJoinOwnGame();
    error NotInvited();
    error NotPlayer();
    error NotYourTurn();
    error InvalidSquare();
    error IllegalMove();
    error InvalidPromotion();
    error MoveTimedOut();
    error NotTimedOut();
    error NoDrawOffer();
    error CannotAcceptOwnDraw();
    error NothingOwed();

    event GameCreated(
        uint256 indexed id,
        address indexed creator,
        uint128 wager,
        uint32 moveTimeout,
        bool playAsWhite,
        address invited
    );
    event GameJoined(uint256 indexed id, address indexed joiner);
    event MoveMade(
        uint256 indexed id,
        address indexed player,
        uint8 from,
        uint8 to,
        uint8 piece,
        uint8 captured,
        uint8 promotion,
        uint16 moveCount
    );
    event DrawOffered(uint256 indexed id, address indexed player);
    event GameEnded(uint256 indexed id, address indexed winner, EndReason endReason);
    event PayoutDeferred(address indexed recipient, uint256 amount);
    event OwedWithdrawn(address indexed recipient, uint256 amount);

    /// @param usdc_ USDC ERC-20 used for all games; must not be zero.
    constructor(IERC20 usdc_) {
        if (address(usdc_) == address(0)) revert ZeroAddress();
        usdc = usdc_;
    }

    /// @notice Read a game's full state; nonexistent IDs revert.
    function getGame(uint256 id) external view returns (Game memory) {
        return _game(id);
    }

    /**
     * @notice Create a game, depositing one wager and choosing your color.
     * @param wager Raw USDC units; zero enables a free game.
     * @param moveTimeout Per-move limit, inclusive range 60 seconds to 30 days.
     * @param playAsWhite Whether the creator occupies the white slot.
     * @param invited Only this account may join, or zero for a public game.
     */
    function createGame(uint128 wager, uint32 moveTimeout, bool playAsWhite, address invited)
        external nonReentrant returns (uint256 id)
    {
        if (moveTimeout < 60 || moveTimeout > 30 days) revert InvalidMoveTimeout();
        if (invited == msg.sender) revert InvalidInvitation();

        id = ++gameCount;
        Game storage g = games[id];
        if (playAsWhite) g.white = msg.sender;
        else g.black = msg.sender;
        g.invited = invited;
        g.wager = wager;
        g.moveTimeout = moveTimeout;
        g.status = Status.Open;
        g.whiteToMove = true;
        g.board = INITIAL_BOARD;

        emit GameCreated(id, msg.sender, wager, moveTimeout, playAsWhite, invited);
        if (wager != 0) usdc.safeTransferFrom(msg.sender, address(this), uint256(wager));
    }

    /// @notice Join an open game, matching its wager. White always moves first.
    function joinGame(uint256 id) external nonReentrant {
        Game storage g = _game(id);
        if (g.status != Status.Open) revert InvalidStatus();
        if (msg.sender == _creator(g)) revert CannotJoinOwnGame();
        if (g.invited != address(0) && msg.sender != g.invited) revert NotInvited();

        if (g.white == address(0)) g.white = msg.sender;
        else g.black = msg.sender;
        g.status = Status.Active;
        g.lastMoveAt = uint40(block.timestamp);
        g.whiteToMove = true;

        emit GameJoined(id, msg.sender);
        if (g.wager != 0) usdc.safeTransferFrom(msg.sender, address(this), uint256(g.wager));
    }

    /// @notice Creator-only cancellation before joining, refunding their wager.
    function cancelGame(uint256 id) external nonReentrant {
        Game storage g = _game(id);
        if (g.status != Status.Open) revert InvalidStatus();
        if (msg.sender != _creator(g)) revert NotCreator();
        _finish(id, g, address(0), EndReason.Cancelled);
    }

    /**
     * @notice Move a piece under the simplified king-capture ruleset.
     * @dev Requires a non-expired timer. Every move clears any draw offer.
     * @param promotion Piece TYPE 2..5 on a pawn's final rank, otherwise zero.
     */
    function makeMove(uint256 id, uint8 from, uint8 to, uint8 promotion) external nonReentrant {
        Game storage g = _activeGame(id);
        if (msg.sender != (g.whiteToMove ? g.white : g.black)) revert NotYourTurn();
        if (_expired(g)) revert MoveTimedOut();
        if (from >= 64 || to >= 64) revert InvalidSquare();
        if (!_canMove(g.board, g.whiteToMove, from, to)) revert IllegalMove();

        uint8 piece = _pieceAt(g.board, from);
        uint8 captured = _pieceAt(g.board, to);
        uint8 placed = piece;
        if ((piece & 7) == 1 && (to / 8 == (g.whiteToMove ? 7 : 0))) {
            if (promotion < 2 || promotion > 5) revert InvalidPromotion();
            placed = (piece & 8) | promotion;
        } else if (promotion != 0) {
            revert InvalidPromotion();
        }

        g.board = _setPiece(_setPiece(g.board, from, 0), to, placed);
        g.moveCount++;
        g.lastMoveAt = uint40(block.timestamp);
        g.whiteToMove = !g.whiteToMove;
        g.drawOfferedBy = 0;
        emit MoveMade(id, msg.sender, from, to, piece, captured, promotion, g.moveCount);
        if ((captured & 7) == 6) _finish(id, g, msg.sender, EndReason.KingCaptured);
    }

    /// @notice Either player may resign an active game, awarding the opponent the pot.
    function resign(uint256 id) external nonReentrant {
        Game storage g = _activeGame(id);
        uint8 side = _playerSide(g);
        _finish(id, g, side == 1 ? g.black : g.white, EndReason.Resigned);
    }

    /// @notice Offer a draw; either player may offer regardless of whose turn it is.
    /// @dev Replaces any existing offer. A subsequent move clears the offer.
    function offerDraw(uint256 id) external nonReentrant {
        Game storage g = _activeGame(id);
        g.drawOfferedBy = _playerSide(g);
        emit DrawOffered(id, msg.sender);
    }

    /// @notice Accept the other player's pending offer and refund both wagers.
    function acceptDraw(uint256 id) external nonReentrant {
        Game storage g = _activeGame(id);
        uint8 side = _playerSide(g);
        if (g.drawOfferedBy == 0) revert NoDrawOffer();
        if (g.drawOfferedBy == side) revert CannotAcceptOwnDraw();
        _finish(id, g, address(0), EndReason.DrawAgreed);
    }

    /// @notice Anyone may settle an expired game in favor of the player not to move.
    /// @dev Expiration is strict: block.timestamp > lastMoveAt + moveTimeout.
    function claimTimeout(uint256 id) external nonReentrant {
        Game storage g = _activeGame(id);
        if (!_expired(g)) revert NotTimedOut();
        _finish(id, g, g.whiteToMove ? g.black : g.white, EndReason.Timeout);
    }

    /// @notice Withdraw all your deferred payouts. A failed transfer preserves credit.
    /// @dev Credit is zeroed before transfer; SafeERC20 failure reverts the whole call.
    function withdrawOwed() external nonReentrant {
        uint256 amount = owed[msg.sender];
        if (amount == 0) revert NothingOwed();
        owed[msg.sender] = 0;
        usdc.safeTransfer(msg.sender, amount);
        emit OwedWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Return a destination bitmask under the same movement rules as makeMove.
     * @dev Bit i represents square i. Empty/wrong-color/invalid pieces yield zero.
     * Out-of-range from reverts. Ignores game status, caller, clocks and check.
     * Pawn final-rank destinations are included: makeMove must additionally supply
     * a valid promotion TYPE. Castling and en passant are never included.
     */
    function legalTargets(uint256 board, bool whiteToMove, uint8 from) public pure returns (uint64 mask) {
        if (from >= 64) revert InvalidSquare();
        uint8 piece = _pieceAt(board, from);
        if (!_isSidePiece(piece, whiteToMove)) return 0;
        for (uint8 to = 0; to < 64; ++to) {
            if (_canMove(board, whiteToMove, from, to)) mask |= uint64(1) << to;
        }
    }

    /// @notice Get geometry-only targets using a game's current board and turn.
    /// @dev Available for any existing game, including open and completed games.
    function legalTargetsFor(uint256 id, uint8 from) external view returns (uint64) {
        Game storage g = _game(id);
        return legalTargets(g.board, g.whiteToMove, from);
    }

    /// @dev Shared, promotion-independent geometry validator. Callers bound squares.
    function _canMove(uint256 board, bool white, uint8 from, uint8 to) internal pure returns (bool) {
        if (from == to) return false;
        uint8 piece = _pieceAt(board, from);
        if (!_isSidePiece(piece, white)) return false;
        uint8 target = _pieceAt(board, to);
        if (target != 0) {
            // Reject malformed nibbles as well as friendly pieces on arbitrary boards.
            if (!_isSidePiece(target, !white)) return false;
        }

        int256 df = int256(uint256(to % 8)) - int256(uint256(from % 8));
        int256 dr = int256(uint256(to / 8)) - int256(uint256(from / 8));
        uint256 af = uint256(df < 0 ? -df : df);
        uint256 ar = uint256(dr < 0 ? -dr : dr);
        uint8 kind = piece & 7;

        if (kind == 1) {
            int256 forward = white ? int256(1) : int256(-1);
            if (af == 1 && dr == forward) return target != 0;
            if (df != 0 || target != 0) return false;
            if (dr == forward) return true;
            if (from / 8 != (white ? 1 : 6) || dr != forward * 2) return false;
            return _pieceAt(board, white ? from + 8 : from - 8) == 0;
        }
        if (kind == 2) return (af == 1 && ar == 2) || (af == 2 && ar == 1);
        if (kind == 6) return af <= 1 && ar <= 1;
        if (kind == 3 && af != ar) return false;
        if (kind == 4 && df != 0 && dr != 0) return false;
        if (kind == 5 && af != ar && df != 0 && dr != 0) return false;
        return _pathClear(board, from, to);
    }

    /// @dev Only called for aligned sliding moves, excluding from == to.
    function _pathClear(uint256 board, uint8 from, uint8 to) internal pure returns (bool) {
        int256 file = int256(uint256(from % 8));
        int256 rank = int256(uint256(from / 8));
        int256 endFile = int256(uint256(to % 8));
        int256 endRank = int256(uint256(to / 8));
        int256 stepFile = endFile > file ? int256(1) : (endFile < file ? int256(-1) : int256(0));
        int256 stepRank = endRank > rank ? int256(1) : (endRank < rank ? int256(-1) : int256(0));
        file += stepFile;
        rank += stepRank;
        while (file != endFile || rank != endRank) {
            if (_pieceAt(board, uint8(uint256(rank * 8 + file))) != 0) return false;
            file += stepFile;
            rank += stepRank;
        }
        return true;
    }

    /// @dev Valid nonempty nibble belonging to the requested side.
    function _isSidePiece(uint8 piece, bool white) internal pure returns (bool) {
        uint8 kind = piece & 7;
        return kind >= 1 && kind <= 6 && ((piece & 8) == 0) == white;
    }

    /// @dev Read a square's raw nibble; square must be less than 64.
    function _pieceAt(uint256 board, uint8 square) internal pure returns (uint8) {
        return uint8((board >> (uint256(square) * 4)) & 15);
    }

    /// @dev Replace a square's nibble; callers supply a valid square and piece.
    function _setPiece(uint256 board, uint8 square, uint8 piece) internal pure returns (uint256) {
        uint256 shift = uint256(square) * 4;
        return (board & ~(uint256(15) << shift)) | (uint256(piece) << shift);
    }

    /// @dev Existing-game lookup shared by all ID-based entry points.
    function _game(uint256 id) internal view returns (Game storage g) {
        g = games[id];
        if (g.status == Status.None) revert GameNotFound();
    }

    /// @dev Existing, active-game lookup.
    function _activeGame(uint256 id) internal view returns (Game storage g) {
        g = _game(id);
        if (g.status != Status.Active) revert InvalidStatus();
    }

    /// @dev Only valid while Open, when exactly one player slot is occupied.
    function _creator(Game storage g) internal view returns (address) {
        return g.white != address(0) ? g.white : g.black;
    }

    /// @dev Player identity as the same 1/2 encoding used for draw offers.
    function _playerSide(Game storage g) internal view returns (uint8) {
        if (msg.sender == g.white) return 1;
        if (msg.sender == g.black) return 2;
        revert NotPlayer();
    }

    /// @dev Widen before adding to avoid narrow-integer deadline arithmetic.
    function _expired(Game storage g) internal view returns (bool) {
        return block.timestamp > uint256(g.lastMoveAt) + uint256(g.moveTimeout);
    }

    /// @dev Finalize every state field before transfers. Callers enforce lifecycle.
    function _finish(uint256 id, Game storage g, address winner, EndReason reason) internal {
        g.status = reason == EndReason.Cancelled ? Status.Cancelled : Status.Finished;
        g.endReason = reason;
        g.winner = winner;
        g.drawOfferedBy = 0;
        emit GameEnded(id, winner, reason);

        uint256 wager = uint256(g.wager);
        if (reason == EndReason.Cancelled) {
            _pay(_creator(g), wager);
        } else if (winner == address(0)) {
            _pay(g.white, wager);
            _pay(g.black, wager);
        } else {
            _pay(winner, wager * 2);
        }
    }

    /// @dev OZ's non-reverting SafeERC20 variant handles false returns and reverts.
    /// Failed transfers accrue credit without blocking other payouts or settlement.
    function _pay(address to, uint256 amount) internal {
        if (amount == 0) return;
        if (!usdc.trySafeTransfer(to, amount)) {
            owed[to] += amount;
            emit PayoutDeferred(to, amount);
        }
    }
}
