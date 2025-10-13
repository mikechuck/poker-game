extends GdUnitTestSuite

var _dm

var royal_flush_hand: Array[Dictionary] = [
	{
		"number": 14,
		"suit": "H"
	},
	{
		"number": 13,
		"suit": "H"
	},
	{
		"number": 12,
		"suit": "H"
	},
	{
		"number": 11,
		"suit": "H"
	},
	{
		"number": 10,
		"suit": "H"
	}
]

var straight_flush_hand: Array[Dictionary] = [
	{
		"number": 9,
		"suit": "H"
	},
	{
		"number": 8,
		"suit": "H"
	},
	{
		"number": 7,
		"suit": "H"
	},
	{
		"number": 6,
		"suit": "H"
	},
	{
		"number": 5,
		"suit": "H"
	}
]

var four_kind_hand: Array[Dictionary] = [
	{
		"number": 14,
		"suit": "C"
	},
	{
		"number": 14,
		"suit": "H"
	},
	{
		"number": 14,
		"suit": "P"
	},
	{
		"number": 14,
		"suit": "D"
	},
	{
		"number": 13,
		"suit": "C"
	},
]

var full_house_hand: Array[Dictionary] = [
	
]
	
	
# --- Test Cases ---

func test_hand() -> void:
	var scene := scene_runner("res://scenes/main.tscn")
	_dm = scene.find_child("DeckManager")
	print("_dm: %s" % _dm)
	
	
