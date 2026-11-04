export const chessAbi = [
  {
    "type": "function",
    "name": "acceptDraw",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "cancelGame",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "claimTimeout",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "createGame",
    "inputs": [
      {
        "name": "wager",
        "type": "uint128",
        "internalType": "uint128"
      },
      {
        "name": "moveTimeout",
        "type": "uint32",
        "internalType": "uint32"
      },
      {
        "name": "playAsWhite",
        "type": "bool",
        "internalType": "bool"
      },
      {
        "name": "invited",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "gameCount",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getGame",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct OnchainChess.Game",
        "components": [
          {
            "name": "white",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "black",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "invited",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "wager",
            "type": "uint128",
            "internalType": "uint128"
          },
          {
            "name": "moveTimeout",
            "type": "uint32",
            "internalType": "uint32"
          },
          {
            "name": "lastMoveAt",
            "type": "uint40",
            "internalType": "uint40"
          },
          {
            "name": "moveCount",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "status",
            "type": "uint8",
            "internalType": "enum OnchainChess.Status"
          },
          {
            "name": "endReason",
            "type": "uint8",
            "internalType": "enum OnchainChess.EndReason"
          },
          {
            "name": "whiteToMove",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "drawOfferedBy",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "winner",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "board",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "joinGame",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "legalTargets",
    "inputs": [
      {
        "name": "board",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "whiteToMove",
        "type": "bool",
        "internalType": "bool"
      },
      {
        "name": "from",
        "type": "uint8",
        "internalType": "uint8"
      }
    ],
    "outputs": [
      {
        "name": "mask",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "legalTargetsFor",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "from",
        "type": "uint8",
        "internalType": "uint8"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "makeMove",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "from",
        "type": "uint8",
        "internalType": "uint8"
      },
      {
        "name": "to",
        "type": "uint8",
        "internalType": "uint8"
      },
      {
        "name": "promotion",
        "type": "uint8",
        "internalType": "uint8"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "offerDraw",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "owed",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "resign",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "usdc",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IERC20"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "withdrawOwed",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "DrawOffered",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "player",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "GameCreated",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "creator",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "wager",
        "type": "uint128",
        "indexed": false,
        "internalType": "uint128"
      },
      {
        "name": "moveTimeout",
        "type": "uint32",
        "indexed": false,
        "internalType": "uint32"
      },
      {
        "name": "playAsWhite",
        "type": "bool",
        "indexed": false,
        "internalType": "bool"
      },
      {
        "name": "invited",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "GameEnded",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "winner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "endReason",
        "type": "uint8",
        "indexed": false,
        "internalType": "enum OnchainChess.EndReason"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "GameJoined",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "joiner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MoveMade",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "player",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "from",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      },
      {
        "name": "to",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      },
      {
        "name": "piece",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      },
      {
        "name": "captured",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      },
      {
        "name": "promotion",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      },
      {
        "name": "moveCount",
        "type": "uint16",
        "indexed": false,
        "internalType": "uint16"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OwedWithdrawn",
    "inputs": [
      {
        "name": "recipient",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "PayoutDeferred",
    "inputs": [
      {
        "name": "recipient",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "CannotAcceptOwnDraw",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CannotJoinOwnGame",
    "inputs": []
  },
  {
    "type": "error",
    "name": "GameNotFound",
    "inputs": []
  },
  {
    "type": "error",
    "name": "IllegalMove",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidInvitation",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidMoveTimeout",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidPromotion",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidSquare",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidStatus",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MoveTimedOut",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NoDrawOffer",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotCreator",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInvited",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotPlayer",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotTimedOut",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotYourTurn",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NothingOwed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SafeERC20FailedOperation",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "ZeroAddress",
    "inputs": []
  }
] as const
