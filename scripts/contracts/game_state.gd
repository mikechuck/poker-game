extends Node
class_name GameState

enum State {
	Lobby = 1,
	PreGame = 2,
	Shuffle = 3,
	SetupPlayers = 4,
	DealHole = 5,
	Ante = 6,
	BetPostHole = 7,
	DealFlop = 8,
	BetPostFlop = 9,
	DealTurn = 10,
	BetPostTurn = 11,
	DealRiver = 12,
	BetPostRiver = 13,
	EndStep = 14,
	PostGame = 15
}
