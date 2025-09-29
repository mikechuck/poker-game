extends Node
class_name GameState

enum State {
	Lobby = 1,
	PreGame = 2,
	Shuffle = 3,
	DealHole = 4,
	Ante = 5,
	BetPostHole = 6,
	DealFlop = 7,
	BetPostFlop = 8,
	DealTurn = 9,
	BetPostTurn = 10,
	DealRiver = 11,
	BetPostRiver = 12,
	EndStep = 13,
	PostGame = 14
}
