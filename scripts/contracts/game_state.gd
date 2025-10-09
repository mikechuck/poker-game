extends Node
class_name GameState

enum State {
	PreHand,
	SetupHand,
	DealHole,
	BetHole,
	DealFlop,
	BetFlop,
	DealTurn,
	BetTurn,
	DealRiver,
	BetRiver,
	HandOver,
	PostHand,
}
