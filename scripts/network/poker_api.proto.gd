extends Node
@warning_ignore_start("unsafe_property_access", "unsafe_call_argument", "unsafe_method_access")
# Package: poker_api

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")

enum GameStatus {
	STARTING = 0,
	ACTIVE = 1,
	ENDED = 2,
} 
 
enum GamePrivacy {
	PUBLIC = 0,
	FRIENDS = 1,
	INVITE = 2,
	PRIVATE = 3,
} 
 
enum RelationshipStatus {
	FRIEND = 0,
	OUTGOING_PENDING = 1,
	INCOMING_PENDING = 2,
	BLOCKED = 3,
	FAVORITE = 4,
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

class ErrorResponse extends Message:
	#1 : message
	var message: String = ""

	#2 : error
	var error: String = ""


	## Init message field values to default value
	func Init() -> void:
		self.message = ""
		self.error = ""

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = ErrorResponse.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "poker_api.ErrorResponse"

	func MergeFrom(other : Message) -> void:
		if other is ErrorResponse:
			self.message += other.message
			self.error += other.error
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.message != "":
			GDScriptUtils.encode_tag(buffer, 1, 9)
			GDScriptUtils.encode_string(buffer, self.message)
		if self.error != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.error)
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
					self.message = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					self.error = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					pass

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["message"] = self.message
		dict["error"] = self.error
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("message"):
			self.message = dict.get("message")
		if dict.has("error"):
			self.error = dict.get("error")

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

	#8 : friendCode
	var friendCode: String = ""


	## Init message field values to default value
	func Init() -> void:
		self.accountId = ""
		self.playerName = ""
		self.createTimeEpochMilliseconds = 0
		self.profilePictureUrl = ""
		self.handsWon = 0
		self.handsPlayed = 0
		self.playerColor = ""
		self.friendCode = ""

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
			self.friendCode += other.friendCode
 
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
		if self.friendCode != "":
			GDScriptUtils.encode_tag(buffer, 8, 9)
			GDScriptUtils.encode_string(buffer, self.friendCode)
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
				8:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					self.friendCode = field_value[GDScriptUtils.VALUE_KEY]
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
		dict["friendCode"] = self.friendCode
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
		if dict.has("friendCode"):
			self.friendCode = dict.get("friendCode")

# =========================================

class AccountRecordList extends Message:
	#1 : records
	var _records: Array[AccountRecord] = []
	var _records_size: int = 0
	## Size of _records
	func records_size() -> int:
		return self._records_size
	## Get _records
	func records() -> Array[AccountRecord]:
		return self._records.slice(0, self._records_size)
	## Get _records item 
	func get_records(index: int) -> AccountRecord: # index begin from 1
		if index > 0 and index <= _records_size and index <= _records.size():
			return self._records[index - 1]
		return null
	## Add _records
	func add_records(item: AccountRecord) -> AccountRecord:
		if self._records_size >= 0 and self._records_size < self._records.size():
			self._records[self._records_size] = item
		else:
			self._records.append(item)
		self._records_size += 1
		return item
	## Append _records
	func append_records(item_array: Array):
		for item in item_array:
			if item is AccountRecord:
				self.add_records(item)
	## Clean _records 
	func clear_records() -> void:
		self._records_size = 0


	## Init message field values to default value
	func Init() -> void:
		self.clear_records

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = AccountRecordList.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "poker_api.AccountRecordList"

	func MergeFrom(other : Message) -> void:
		if other is AccountRecordList:
			self._records = self._records.slice(0, _records_size)
			self._records.append_array(other._records.slice(0, other._records_size))
			self._records_size += other._records_size
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		for item in self._records:
			GDScriptUtils.encode_tag(buffer, 1, 11)
			GDScriptUtils.encode_message(buffer, item)
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
					var sub__records = AccountRecord.new()
					var field_value = GDScriptUtils.decode_message(data, pos, sub__records)
					self.add_records(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					pass

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["records"] = []
		for index in range(1, self._records_size + 1):
			var item = self.get_records(index)
			dict["records"].append(item.SerializeToDictionary())
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		self.clear_records()
		if dict.has("records"):
			var list = dict["records"]
			for item in list:
				var item_msg = AccountRecord.new()
				item_msg.ParseFromDictionary(item)
				self.add_records(item_msg)

# =========================================

class GameRecord extends Message:
	#1 : gameId
	var gameId: String = ""

	#2 : hostAccountId
	var hostAccountId: String = ""

	#3 : gameStatus
	var gameStatus: GameStatus = 0

	#4 : createTimeEpochMilliseconds
	var createTimeEpochMilliseconds: int = 0

	#5 : endTimeEpochMilliseconds
	var endTimeEpochMilliseconds: int = 0

	#6 : port
	var port: int = 0

	#7 : blindChips
	var blindChips: int = 0

	#8 : buyInChips
	var buyInChips: int = 0

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

	#12 : gamePrivacy
	var gamePrivacy: GamePrivacy = 0


	## Init message field values to default value
	func Init() -> void:
		self.gameId = ""
		self.hostAccountId = ""
		self.gameStatus = 0
		self.createTimeEpochMilliseconds = 0
		self.endTimeEpochMilliseconds = 0
		self.port = 0
		self.blindChips = 0
		self.buyInChips = 0
		self.chipRatio = 0
		self.handsPlayed = 0
		self.clear_connectedPlayers
		self.gamePrivacy = 0

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
			self.hostAccountId += other.hostAccountId
			self.gameStatus = other.gameStatus
			self.createTimeEpochMilliseconds += other.createTimeEpochMilliseconds
			self.endTimeEpochMilliseconds += other.endTimeEpochMilliseconds
			self.port += other.port
			self.blindChips += other.blindChips
			self.buyInChips += other.buyInChips
			self.chipRatio += other.chipRatio
			self.handsPlayed += other.handsPlayed
			self._connectedPlayers = self._connectedPlayers.slice(0, _connectedPlayers_size)
			self._connectedPlayers.append_array(other._connectedPlayers.slice(0, other._connectedPlayers_size))
			self._connectedPlayers_size += other._connectedPlayers_size
			self.gamePrivacy = other.gamePrivacy
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.gameId != "":
			GDScriptUtils.encode_tag(buffer, 1, 9)
			GDScriptUtils.encode_string(buffer, self.gameId)
		if self.hostAccountId != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.hostAccountId)
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
		if self.blindChips != 0:
			GDScriptUtils.encode_tag(buffer, 7, 5)
			GDScriptUtils.encode_varint(buffer, self.blindChips)
		if self.buyInChips != 0:
			GDScriptUtils.encode_tag(buffer, 8, 5)
			GDScriptUtils.encode_varint(buffer, self.buyInChips)
		if self.chipRatio != 0:
			GDScriptUtils.encode_tag(buffer, 9, 5)
			GDScriptUtils.encode_varint(buffer, self.chipRatio)
		if self.handsPlayed != 0:
			GDScriptUtils.encode_tag(buffer, 10, 5)
			GDScriptUtils.encode_varint(buffer, self.handsPlayed)
		for item in self._connectedPlayers:
			GDScriptUtils.encode_tag(buffer, 11, 9)
			GDScriptUtils.encode_string(buffer, item)
		if self.gamePrivacy != 0:
			GDScriptUtils.encode_tag(buffer, 12, 14)
			GDScriptUtils.encode_varint(buffer, self.gamePrivacy)
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
					self.hostAccountId = field_value[GDScriptUtils.VALUE_KEY]
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
					self.blindChips = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				8:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.buyInChips = field_value[GDScriptUtils.VALUE_KEY]
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
				12:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.gamePrivacy = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					pass

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["gameId"] = self.gameId
		dict["hostAccountId"] = self.hostAccountId
		dict["gameStatus"] = self.gameStatus
		dict["createTimeEpochMilliseconds"] = self.createTimeEpochMilliseconds
		dict["endTimeEpochMilliseconds"] = self.endTimeEpochMilliseconds
		dict["port"] = self.port
		dict["blindChips"] = self.blindChips
		dict["buyInChips"] = self.buyInChips
		dict["chipRatio"] = self.chipRatio
		dict["handsPlayed"] = self.handsPlayed
		dict["connectedPlayers"] = self._connectedPlayers
		dict["gamePrivacy"] = self.gamePrivacy
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("gameId"):
			self.gameId = dict.get("gameId")
		if dict.has("hostAccountId"):
			self.hostAccountId = dict.get("hostAccountId")
		if dict.has("gameStatus"):
			self.gameStatus = dict.get("gameStatus")
		if dict.has("createTimeEpochMilliseconds"):
			self.createTimeEpochMilliseconds = dict.get("createTimeEpochMilliseconds")
		if dict.has("endTimeEpochMilliseconds"):
			self.endTimeEpochMilliseconds = dict.get("endTimeEpochMilliseconds")
		if dict.has("port"):
			self.port = dict.get("port")
		if dict.has("blindChips"):
			self.blindChips = dict.get("blindChips")
		if dict.has("buyInChips"):
			self.buyInChips = dict.get("buyInChips")
		if dict.has("chipRatio"):
			self.chipRatio = dict.get("chipRatio")
		if dict.has("handsPlayed"):
			self.handsPlayed = dict.get("handsPlayed")
		self.clear_connectedPlayers()
		if dict.has("connectedPlayers"):
			var list = dict["connectedPlayers"]
			for item in list:
				self.add_connectedPlayers(item)
		if dict.has("gamePrivacy"):
			self.gamePrivacy = dict.get("gamePrivacy")

# =========================================

class GameRecordList extends Message:
	#1 : records
	var _records: Array[GameRecord] = []
	var _records_size: int = 0
	## Size of _records
	func records_size() -> int:
		return self._records_size
	## Get _records
	func records() -> Array[GameRecord]:
		return self._records.slice(0, self._records_size)
	## Get _records item 
	func get_records(index: int) -> GameRecord: # index begin from 1
		if index > 0 and index <= _records_size and index <= _records.size():
			return self._records[index - 1]
		return null
	## Add _records
	func add_records(item: GameRecord) -> GameRecord:
		if self._records_size >= 0 and self._records_size < self._records.size():
			self._records[self._records_size] = item
		else:
			self._records.append(item)
		self._records_size += 1
		return item
	## Append _records
	func append_records(item_array: Array):
		for item in item_array:
			if item is GameRecord:
				self.add_records(item)
	## Clean _records 
	func clear_records() -> void:
		self._records_size = 0


	## Init message field values to default value
	func Init() -> void:
		self.clear_records

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = GameRecordList.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "poker_api.GameRecordList"

	func MergeFrom(other : Message) -> void:
		if other is GameRecordList:
			self._records = self._records.slice(0, _records_size)
			self._records.append_array(other._records.slice(0, other._records_size))
			self._records_size += other._records_size
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		for item in self._records:
			GDScriptUtils.encode_tag(buffer, 1, 11)
			GDScriptUtils.encode_message(buffer, item)
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
					var sub__records = GameRecord.new()
					var field_value = GDScriptUtils.decode_message(data, pos, sub__records)
					self.add_records(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					pass

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["records"] = []
		for index in range(1, self._records_size + 1):
			var item = self.get_records(index)
			dict["records"].append(item.SerializeToDictionary())
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		self.clear_records()
		if dict.has("records"):
			var list = dict["records"]
			for item in list:
				var item_msg = GameRecord.new()
				item_msg.ParseFromDictionary(item)
				self.add_records(item_msg)

# =========================================

class JoinTokenRecord extends Message:
	#1 : accountId
	var accountId: String = ""

	#2 : gameId
	var gameId: String = ""

	#3 : joinToken
	var joinToken: String = ""

	#4 : expirationTimeEpochMilliseconds
	var expirationTimeEpochMilliseconds: int = 0


	## Init message field values to default value
	func Init() -> void:
		self.accountId = ""
		self.gameId = ""
		self.joinToken = ""
		self.expirationTimeEpochMilliseconds = 0

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = JoinTokenRecord.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "poker_api.JoinTokenRecord"

	func MergeFrom(other : Message) -> void:
		if other is JoinTokenRecord:
			self.accountId += other.accountId
			self.gameId += other.gameId
			self.joinToken += other.joinToken
			self.expirationTimeEpochMilliseconds += other.expirationTimeEpochMilliseconds
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.accountId != "":
			GDScriptUtils.encode_tag(buffer, 1, 9)
			GDScriptUtils.encode_string(buffer, self.accountId)
		if self.gameId != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.gameId)
		if self.joinToken != "":
			GDScriptUtils.encode_tag(buffer, 3, 9)
			GDScriptUtils.encode_string(buffer, self.joinToken)
		if self.expirationTimeEpochMilliseconds != 0:
			GDScriptUtils.encode_tag(buffer, 4, 3)
			GDScriptUtils.encode_varint(buffer, self.expirationTimeEpochMilliseconds)
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
					self.gameId = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					self.joinToken = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.expirationTimeEpochMilliseconds = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					pass

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["accountId"] = self.accountId
		dict["gameId"] = self.gameId
		dict["joinToken"] = self.joinToken
		dict["expirationTimeEpochMilliseconds"] = self.expirationTimeEpochMilliseconds
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("accountId"):
			self.accountId = dict.get("accountId")
		if dict.has("gameId"):
			self.gameId = dict.get("gameId")
		if dict.has("joinToken"):
			self.joinToken = dict.get("joinToken")
		if dict.has("expirationTimeEpochMilliseconds"):
			self.expirationTimeEpochMilliseconds = dict.get("expirationTimeEpochMilliseconds")

# =========================================

class RelationshipRecord extends Message:
	#1 : accountId
	var accountId: String = ""

	#2 : peerAccountId
	var peerAccountId: String = ""

	#3 : relationshipStatus
	var relationshipStatus: RelationshipStatus = 0

	#4 : nickname
	var nickname: String = ""

	#5 : createTimeEpochMilliseconds
	var createTimeEpochMilliseconds: int = 0


	## Init message field values to default value
	func Init() -> void:
		self.accountId = ""
		self.peerAccountId = ""
		self.relationshipStatus = 0
		self.nickname = ""
		self.createTimeEpochMilliseconds = 0

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = RelationshipRecord.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "poker_api.RelationshipRecord"

	func MergeFrom(other : Message) -> void:
		if other is RelationshipRecord:
			self.accountId += other.accountId
			self.peerAccountId += other.peerAccountId
			self.relationshipStatus = other.relationshipStatus
			self.nickname += other.nickname
			self.createTimeEpochMilliseconds += other.createTimeEpochMilliseconds
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.accountId != "":
			GDScriptUtils.encode_tag(buffer, 1, 9)
			GDScriptUtils.encode_string(buffer, self.accountId)
		if self.peerAccountId != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.peerAccountId)
		if self.relationshipStatus != 0:
			GDScriptUtils.encode_tag(buffer, 3, 14)
			GDScriptUtils.encode_varint(buffer, self.relationshipStatus)
		if self.nickname != "":
			GDScriptUtils.encode_tag(buffer, 4, 9)
			GDScriptUtils.encode_string(buffer, self.nickname)
		if self.createTimeEpochMilliseconds != 0:
			GDScriptUtils.encode_tag(buffer, 5, 3)
			GDScriptUtils.encode_varint(buffer, self.createTimeEpochMilliseconds)
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
					self.peerAccountId = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.relationshipStatus = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					self.nickname = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					self.createTimeEpochMilliseconds = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					pass

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["accountId"] = self.accountId
		dict["peerAccountId"] = self.peerAccountId
		dict["relationshipStatus"] = self.relationshipStatus
		dict["nickname"] = self.nickname
		dict["createTimeEpochMilliseconds"] = self.createTimeEpochMilliseconds
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("accountId"):
			self.accountId = dict.get("accountId")
		if dict.has("peerAccountId"):
			self.peerAccountId = dict.get("peerAccountId")
		if dict.has("relationshipStatus"):
			self.relationshipStatus = dict.get("relationshipStatus")
		if dict.has("nickname"):
			self.nickname = dict.get("nickname")
		if dict.has("createTimeEpochMilliseconds"):
			self.createTimeEpochMilliseconds = dict.get("createTimeEpochMilliseconds")

# =========================================

class RelationshipRecordList extends Message:
	#1 : relationships
	var _relationships: Array[RelationshipRecord] = []
	var _relationships_size: int = 0
	## Size of _relationships
	func relationships_size() -> int:
		return self._relationships_size
	## Get _relationships
	func relationships() -> Array[RelationshipRecord]:
		return self._relationships.slice(0, self._relationships_size)
	## Get _relationships item 
	func get_relationships(index: int) -> RelationshipRecord: # index begin from 1
		if index > 0 and index <= _relationships_size and index <= _relationships.size():
			return self._relationships[index - 1]
		return null
	## Add _relationships
	func add_relationships(item: RelationshipRecord) -> RelationshipRecord:
		if self._relationships_size >= 0 and self._relationships_size < self._relationships.size():
			self._relationships[self._relationships_size] = item
		else:
			self._relationships.append(item)
		self._relationships_size += 1
		return item
	## Append _relationships
	func append_relationships(item_array: Array):
		for item in item_array:
			if item is RelationshipRecord:
				self.add_relationships(item)
	## Clean _relationships 
	func clear_relationships() -> void:
		self._relationships_size = 0


	## Init message field values to default value
	func Init() -> void:
		self.clear_relationships

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = RelationshipRecordList.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "poker_api.RelationshipRecordList"

	func MergeFrom(other : Message) -> void:
		if other is RelationshipRecordList:
			self._relationships = self._relationships.slice(0, _relationships_size)
			self._relationships.append_array(other._relationships.slice(0, other._relationships_size))
			self._relationships_size += other._relationships_size
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		for item in self._relationships:
			GDScriptUtils.encode_tag(buffer, 1, 11)
			GDScriptUtils.encode_message(buffer, item)
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
					var sub__relationships = RelationshipRecord.new()
					var field_value = GDScriptUtils.decode_message(data, pos, sub__relationships)
					self.add_relationships(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					pass

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["relationships"] = []
		for index in range(1, self._relationships_size + 1):
			var item = self.get_relationships(index)
			dict["relationships"].append(item.SerializeToDictionary())
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		self.clear_relationships()
		if dict.has("relationships"):
			var list = dict["relationships"]
			for item in list:
				var item_msg = RelationshipRecord.new()
				item_msg.ParseFromDictionary(item)
				self.add_relationships(item_msg)

# =========================================


