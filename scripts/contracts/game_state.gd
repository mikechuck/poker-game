extends Node
class_name GameState

enum State {
	PreHand,
	SetupHand,
	DealHole,
	Ante,
	BetHole,
	DealFlop,
	BetFlop,
	DealTurn,
	BetTurn,
	DealRiver,
	BetRiver,
	EndStep,
	PostHand,
}
