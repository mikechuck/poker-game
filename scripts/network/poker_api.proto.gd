@warning_ignore_start("unsafe_property_access", "unsafe_call_argument", "unsafe_method_access")
# Package: poker_api

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")

enum GameStatus {
	STARTING = 0,
	STARTED = 1,
	ENDED = 2,
} 
 
class HttpResponseWrapper extends Message:
	#1 : result
	var result: int = 0

	#2 : response_code
	var response_code: int = 0

	#3 : response_headers
	var _response_headers: Array[String] = []
	var _response_headers_size: int = 0
	## Size of _response_headers
	func response_headers_size() -> int:
		return self._response_headers_size
	## Get _response_headers
	func response_headers() -> Array[String]:
		return self._response_headers.slice(0, self._response_headers_size)
	## Get _response_headers item 
	func get_response_headers(index: int) -> String: # index begin from 1
		if index > 0 and index <= _response_headers_size and index <= _response_headers.size():
			return self._response_headers[index - 1]
		return ""
	## Add _response_headers
	func add_response_headers(item: String) -> String:
		if self._response_headers_size >= 0 and self._response_headers_size < self._response_headers.size():
			self._response_headers[self._response_headers_size] = item
		else:
			self._response_headers.append(item)
		self._response_headers_size += 1
		return item
	## Append _response_headers
	func append_response_headers(item_array: Array):
		for item in item_array:
			if item is String:
				self.add_response_headers(item)
	## Clean _response_headers 
	func clear_response_headers() -> void:
		self._response_headers_size = 0

	#4 : response_body
	var response_body: PackedByteArray = PackedByteArray()


	## Init message field values to default value
	func Init() -> void:
		self.result = 0
		self.response_code = 0
		self.clear_response_headers
		self.response_body = PackedByteArray()

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = HttpResponseWrapper.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "poker_api.HttpResponseWrapper"

	func MergeFrom(other : Message) -> void:
		if other is HttpResponseWrapper:
			self.result += other.result
			self.response_code += other.response_code
			self._response_headers = self._response_headers.slice(0, _response_headers_size)
			self._response_headers.append_array(other._response_headers.slice(0, other._response_headers_size))
			self._response_headers_size += other._response_headers_size
			self.response_body.append_array(other.response_body)
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.result != 0:
			GDScriptUtils.encode_tag(buffer, 1, 5)
			GDScriptUtils.encode_varint(buffer, self.result)
		if self.response_code != 0:
			GDScriptUtils.encode_tag(buffer, 2, 5)
			GDScriptUtils.encode_varint(buffer, self.response_code)
		for item in self._response_headers:
			GDScriptUtils.encode_tag(buffer, 3, 9)
			GDScriptUtils.encode_string(buffer, item)
		if len(self.response_body) > 0:
			GDScriptUtils.encode_tag(buffer, 4, 12)
			GDScriptUtils.encode_bytes(buffer, self.response_body)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		var size = data.size()
		var pos = 0
 
		while pos < size:
			var tag = GDScriptUtils.decode_tag(data, pos)
			var field_number = tag[GDScriptUtils.VALUE_KEY]
			pos += tag[GDScriptUtils.SIZE_KEY]
 
			match field_number:
				1:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.result = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.response_code = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					self.add_response_headers(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_bytes(data, pos, self)
					self.response_body = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					pass

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["result"] = self.result
		dict["response_code"] = self.response_code
		dict["response_headers"] = self._response_headers
		dict["response_body"] = self.response_body
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("result"):
			self.result = dict.get("result")
		if dict.has("response_code"):
			self.response_code = dict.get("response_code")
		self.clear_response_headers()
		if dict.has("response_headers"):
			var list = dict["response_headers"]
			for item in list:
				self.add_response_headers(item)
		if dict.has("response_body"):
			self.response_body = dict.get("response_body")

# =========================================

class AccountRecord extends Message:
	#1 : accountId
	var accountId: String = ""

	#2 : playerName
	var playerName: String = ""

	#3 : createTimeEpochMilliseconds
	var createTimeEpochMilliseconds: int = 0

	#4 : profilePictureUrl
	var profilePictureUrl: String = ""

	#5 : handsWon
	var handsWon: int = 0

	#6 : handsPlayed
	var handsPlayed: int = 0

	#7 : playerColor
	var playerColor: String = ""


	## Init message field values to default value
	func Init() -> void:
		self.accountId = ""
		self.playerName = ""
		self.createTimeEpochMilliseconds = 0
		self.profilePictureUrl = ""
		self.handsWon = 0
		self.handsPlayed = 0
		self.playerColor = ""

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = AccountRecord.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "poker_api.AccountRecord"

	func MergeFrom(other : Message) -> void:
		if other is AccountRecord:
			self.accountId += other.accountId
			self.playerName += other.playerName
			self.createTimeEpochMilliseconds += other.createTimeEpochMilliseconds
			self.profilePictureUrl += other.profilePictureUrl
			self.handsWon += other.handsWon
			self.handsPlayed += other.handsPlayed
			self.playerColor += other.playerColor
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.accountId != "":
			GDScriptUtils.encode_tag(buffer, 1, 9)
			GDScriptUtils.encode_string(buffer, self.accountId)
		if self.playerName != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.playerName)
		if self.createTimeEpochMilliseconds != 0:
			GDScriptUtils.encode_tag(buffer, 3, 3)
			GDScriptUtils.encode_varint(buffer, self.createTimeEpochMilliseconds)
		if self.profilePictureUrl != "":
			GDScriptUtils.encode_tag(buffer, 4, 9)
			GDScriptUtils.encode_string(buffer, self.profilePictureUrl)
		if self.handsWon != 0:
			GDScriptUtils.encode_tag(buffer, 5, 5)
			GDScriptUtils.encode_varint(buffer, self.handsWon)
		if self.handsPlayed != 0:
			GDScriptUtils.encode_tag(buffer, 6, 5)
			GDScriptUtils.encode_varint(buffer, self.handsPlayed)
		if self.playerColor != "":
			GDScriptUtils.encode_tag(buffer, 7, 9)
			GDScriptUtils.encode_string(buffer, self.playerColor)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		var size = data.size()
		var pos = 0
 
		while pos < size:
			var tag = GDScriptUtils.decode_tag(data, pos)
			var field_number = tag[GDScriptUtils.VALUE_KEY]
			pos += tag[GDScriptUtils.SIZE_KEY]
 
			match field_number:
				1:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					self.accountId = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					self.playerName = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.createTimeEpochMilliseconds = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					self.profilePictureUrl = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.handsWon = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				6:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.handsPlayed = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				7:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					self.playerColor = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					pass

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["accountId"] = self.accountId
		dict["playerName"] = self.playerName
		dict["createTimeEpochMilliseconds"] = self.createTimeEpochMilliseconds
		dict["profilePictureUrl"] = self.profilePictureUrl
		dict["handsWon"] = self.handsWon
		dict["handsPlayed"] = self.handsPlayed
		dict["playerColor"] = self.playerColor
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("accountId"):
			self.accountId = dict.get("accountId")
		if dict.has("playerName"):
			self.playerName = dict.get("playerName")
		if dict.has("createTimeEpochMilliseconds"):
			self.createTimeEpochMilliseconds = dict.get("createTimeEpochMilliseconds")
		if dict.has("profilePictureUrl"):
			self.profilePictureUrl = dict.get("profilePictureUrl")
		if dict.has("handsWon"):
			self.handsWon = dict.get("handsWon")
		if dict.has("handsPlayed"):
			self.handsPlayed = dict.get("handsPlayed")
		if dict.has("playerColor"):
			self.playerColor = dict.get("playerColor")

# =========================================

class GameRecord extends Message:
	#1 : gameId
	var gameId: String = ""

	#2 : hostPlayerId
	var hostPlayerId: String = ""

	#3 : gameStatus
	var gameStatus: GameStatus = 0

	#4 : createTimeEpochMilliseconds
	var createTimeEpochMilliseconds: int = 0

	#5 : endTimeEpochMilliseconds
	var endTimeEpochMilliseconds: int = 0

	#6 : port
	var port: int = 0

	#7 : blindValue
	var blindValue: int = 0

	#8 : buyInDollars
	var buyInDollars: int = 0

	#9 : chipRatio
	var chipRatio: int = 0

	#10 : handsPlayed
	var handsPlayed: int = 0

	#11 : connectedPlayers
	var _connectedPlayers: Array[String] = []
	var _connectedPlayers_size: int = 0
	## Size of _connectedPlayers
	func connectedPlayers_size() -> int:
		return self._connectedPlayers_size
	## Get _connectedPlayers
	func connectedPlayers() -> Array[String]:
		return self._connectedPlayers.slice(0, self._connectedPlayers_size)
	## Get _connectedPlayers item 
	func get_connectedPlayers(index: int) -> String: # index begin from 1
		if index > 0 and index <= _connectedPlayers_size and index <= _connectedPlayers.size():
			return self._connectedPlayers[index - 1]
		return ""
	## Add _connectedPlayers
	func add_connectedPlayers(item: String) -> String:
		if self._connectedPlayers_size >= 0 and self._connectedPlayers_size < self._connectedPlayers.size():
			self._connectedPlayers[self._connectedPlayers_size] = item
		else:
			self._connectedPlayers.append(item)
		self._connectedPlayers_size += 1
		return item
	## Append _connectedPlayers
	func append_connectedPlayers(item_array: Array):
		for item in item_array:
			if item is String:
				self.add_connectedPlayers(item)
	## Clean _connectedPlayers 
	func clear_connectedPlayers() -> void:
		self._connectedPlayers_size = 0


	## Init message field values to default value
	func Init() -> void:
		self.gameId = ""
		self.hostPlayerId = ""
		self.gameStatus = 0
		self.createTimeEpochMilliseconds = 0
		self.endTimeEpochMilliseconds = 0
		self.port = 0
		self.blindValue = 0
		self.buyInDollars = 0
		self.chipRatio = 0
		self.handsPlayed = 0
		self.clear_connectedPlayers

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = GameRecord.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "poker_api.GameRecord"

	func MergeFrom(other : Message) -> void:
		if other is GameRecord:
			self.gameId += other.gameId
			self.hostPlayerId += other.hostPlayerId
			self.gameStatus = other.gameStatus
			self.createTimeEpochMilliseconds += other.createTimeEpochMilliseconds
			self.endTimeEpochMilliseconds += other.endTimeEpochMilliseconds
			self.port += other.port
			self.blindValue += other.blindValue
			self.buyInDollars += other.buyInDollars
			self.chipRatio += other.chipRatio
			self.handsPlayed += other.handsPlayed
			self._connectedPlayers = self._connectedPlayers.slice(0, _connectedPlayers_size)
			self._connectedPlayers.append_array(other._connectedPlayers.slice(0, other._connectedPlayers_size))
			self._connectedPlayers_size += other._connectedPlayers_size
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.gameId != "":
			GDScriptUtils.encode_tag(buffer, 1, 9)
			GDScriptUtils.encode_string(buffer, self.gameId)
		if self.hostPlayerId != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.hostPlayerId)
		if self.gameStatus != 0:
			GDScriptUtils.encode_tag(buffer, 3, 14)
			GDScriptUtils.encode_varint(buffer, self.gameStatus)
		if self.createTimeEpochMilliseconds != 0:
			GDScriptUtils.encode_tag(buffer, 4, 3)
			GDScriptUtils.encode_varint(buffer, self.createTimeEpochMilliseconds)
		if self.endTimeEpochMilliseconds != 0:
			GDScriptUtils.encode_tag(buffer, 5, 3)
			GDScriptUtils.encode_varint(buffer, self.endTimeEpochMilliseconds)
		if self.port != 0:
			GDScriptUtils.encode_tag(buffer, 6, 5)
			GDScriptUtils.encode_varint(buffer, self.port)
		if self.blindValue != 0:
			GDScriptUtils.encode_tag(buffer, 7, 5)
			GDScriptUtils.encode_varint(buffer, self.blindValue)
		if self.buyInDollars != 0:
			GDScriptUtils.encode_tag(buffer, 8, 5)
			GDScriptUtils.encode_varint(buffer, self.buyInDollars)
		if self.chipRatio != 0:
			GDScriptUtils.encode_tag(buffer, 9, 5)
			GDScriptUtils.encode_varint(buffer, self.chipRatio)
		if self.handsPlayed != 0:
			GDScriptUtils.encode_tag(buffer, 10, 5)
			GDScriptUtils.encode_varint(buffer, self.handsPlayed)
		for item in self._connectedPlayers:
			GDScriptUtils.encode_tag(buffer, 11, 9)
			GDScriptUtils.encode_string(buffer, item)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		var size = data.size()
		var pos = 0
 
		while pos < size:
			var tag = GDScriptUtils.decode_tag(data, pos)
			var field_number = tag[GDScriptUtils.VALUE_KEY]
			pos += tag[GDScriptUtils.SIZE_KEY]
 
			match field_number:
				1:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					self.gameId = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					self.hostPlayerId = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.gameStatus = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.createTimeEpochMilliseconds = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.endTimeEpochMilliseconds = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				6:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.port = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				7:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.blindValue = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				8:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.buyInDollars = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				9:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.chipRatio = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				10:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.handsPlayed = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				11:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					self.add_connectedPlayers(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					pass

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["gameId"] = self.gameId
		dict["hostPlayerId"] = self.hostPlayerId
		dict["gameStatus"] = self.gameStatus
		dict["createTimeEpochMilliseconds"] = self.createTimeEpochMilliseconds
		dict["endTimeEpochMilliseconds"] = self.endTimeEpochMilliseconds
		dict["port"] = self.port
		dict["blindValue"] = self.blindValue
		dict["buyInDollars"] = self.buyInDollars
		dict["chipRatio"] = self.chipRatio
		dict["handsPlayed"] = self.handsPlayed
		dict["connectedPlayers"] = self._connectedPlayers
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("gameId"):
			self.gameId = dict.get("gameId")
		if dict.has("hostPlayerId"):
			self.hostPlayerId = dict.get("hostPlayerId")
		if dict.has("gameStatus"):
			self.gameStatus = dict.get("gameStatus")
		if dict.has("createTimeEpochMilliseconds"):
			self.createTimeEpochMilliseconds = dict.get("createTimeEpochMilliseconds")
		if dict.has("endTimeEpochMilliseconds"):
			self.endTimeEpochMilliseconds = dict.get("endTimeEpochMilliseconds")
		if dict.has("port"):
			self.port = dict.get("port")
		if dict.has("blindValue"):
			self.blindValue = dict.get("blindValue")
		if dict.has("buyInDollars"):
			self.buyInDollars = dict.get("buyInDollars")
		if dict.has("chipRatio"):
			self.chipRatio = dict.get("chipRatio")
		if dict.has("handsPlayed"):
			self.handsPlayed = dict.get("handsPlayed")
		self.clear_connectedPlayers()
		if dict.has("connectedPlayers"):
			var list = dict["connectedPlayers"]
			for item in list:
				self.add_connectedPlayers(item)

# =========================================
