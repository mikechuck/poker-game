# Server-Side Authentication & Balance Management Refactor Plan

## Problem Statement
Currently, the client fetches balance from chips-api and sends it to the server. The server tries to use `AccessTokenService.get_user_id()` which fails because it cannot access browser `sessionStorage`. This creates security and reliability issues:
- Server cannot validate balance independently
- Server cannot make authoritative API calls
- Token validation happens on client (not secure)

## Solution Overview
Move all authentication and chips-api interactions to the server. The client sends its JWT token to the server upon connection, and the server:
1. Stores the JWT per connected player
2. Extracts user_id from JWT
3. Fetches balance from chips-api using stored JWT
4. Manages all balance updates to chips-api

## Implementation Steps

### Step 1: Extend ConnectedPlayer Data Structure
**File**: `poker-game/scripts/contracts/connected_player.gd`

Add fields to store JWT and user_id:
- `var jwt_token: String = ""` - Store the JWT token from client
- `var user_id: String = ""` - Store extracted user_id from JWT

Update methods:
- `clone()` - Include new fields
- `to_dict()` - Include new fields (but exclude `jwt_token` for security - don't send token to clients)
- `from_dict()` - Handle new fields (note: `jwt_token` won't be in dict from clients)

**Security Note**: `jwt_token` should NOT be serialized and sent to clients. Only the server needs it.

---

### Step 2: Create JWT Utility Functions for Server
**File**: `poker-game/scripts/utilities/jwt_utils.gd` (NEW FILE)

Create utility functions that work on the server (not using browser storage):
- `extract_user_id_from_token(jwt_token: String) -> String` - Extract user_id from JWT payload `sub` claim
- `decode_jwt_payload(jwt_token: String) -> Dictionary` - Decode JWT payload (same logic as AccessTokenService but standalone)

This avoids dependency on AccessTokenService which requires browser environment.

---

### Step 3: Create New RPC for Client to Send JWT
**File**: `poker-game/scripts/managers/server_manager.gd`

Add new RPC function:
```gdscript
@rpc("reliable", "any_peer")
func register_player_auth(jwt_token: String):
    """
    RPC called by client to register their JWT token with the server.
    Server will extract user_id and fetch balance from chips-api.
    """
```

Flow:
1. Verify client_id matches a connected player
2. Extract user_id from JWT using `JWTUtils.extract_user_id_from_token()`
3. Store JWT and user_id in `ConnectedPlayer`
4. Call `_fetch_player_balance_from_api(client_id)` to fetch balance

**Error Handling**: If JWT is invalid or user_id extraction fails, disconnect player with error message.

---

### Step 4: Move Balance Fetching to Server
**File**: `poker-game/scripts/managers/server_manager.gd`

Add function to fetch balance from chips-api:
```gdscript
func _fetch_player_balance_from_api(client_id: int):
    """
    Fetch player balance from chips-api using stored JWT token.
    Called after player registers their JWT.
    """
```

Flow:
1. Get `ConnectedPlayer` for `client_id`
2. Verify JWT and user_id are set
3. Call `chips_api_service.get_chips(user_id, jwt_token, callback)`
4. On success, update `connected_player.account_total_cash`
5. If player is already seated, update `seat.hand_cash`
6. If balance fetch fails, disconnect player (no fallback)

**Error Handling**:
- 404: Create user with 0 balance
- Any other error: Disconnect player

---

### Step 5: Update ChipsApiService to Accept JWT Parameter
**File**: `poker-game/scripts/managers/chips_api_service.gd`

Modify methods to accept JWT token as parameter (instead of reading from AccessTokenService):

```gdscript
func get_chips(user_id: String, jwt_token: String, callback: Callable) -> void:
    # Use provided jwt_token instead of AccessTokenService.get_token()
    
func update_chips(user_id: String, chips_balance: int, jwt_token: String, callback: Callable) -> void:
    # Use provided jwt_token instead of AccessTokenService.get_token()
```

This makes the service work on both client and server.

---

### Step 6: Update Client to Send JWT on Connection
**File**: `poker-game/scripts/managers/client_manager.gd`

Modify `_on_connected_to_server()`:
1. Get JWT token from `AccessTokenService.get_token()`
2. If token is empty, disconnect with error
3. Call `server_manager.register_player_auth.rpc_id(1, token)`
4. Remove all balance fetching logic from client
5. Remove `_register_player_balance()`, `_on_balance_fetched()`, `_handle_balance_error()` functions

The client no longer fetches balance - it only sends the JWT and waits for server to manage everything.

---

### Step 7: Update Game Manager to Use Stored JWT for Balance Updates
**File**: `poker-game/scripts/managers/game_manager.gd`

Modify `state_end_step()`:
1. Get winner's `ConnectedPlayer` object
2. Use `connected_player.user_id` and `connected_player.jwt_token` (instead of `AccessTokenService`)
3. Call `chips_api_service.update_chips(user_id, balance, jwt_token, callback)`

**Error Handling**: Log errors but don't disconnect (game already completed)

---

### Step 8: Remove register_player_with_balance RPC
**File**: `poker-game/scripts/managers/server_manager.gd`

Remove the old `register_player_with_balance()` RPC function since:
- Server now fetches balance directly
- Client no longer sends balance

---

### Step 9: Update Server Peer Connection Handler
**File**: `poker-game/scripts/managers/server_manager.gd`

Modify `_on_peer_connected()`:
- Remove comment about waiting for client to provide balance
- Set `account_total_cash = -1` (still indicates not loaded)
- Server will fetch balance after client sends JWT via `register_player_auth` RPC

---

### Step 10: Ensure ChipsApiService is Available on Server
**File**: `poker-game/scenes/game.tscn`

Verify `ChipsApiService` node exists in the scene tree (it should already be there).

---

## Data Flow After Changes

### Client Connection Flow:
1. Client connects to server → `_on_peer_connected()` fires on server
2. Client calls `register_player_auth.rpc_id(1, jwt_token)` → sends JWT
3. Server stores JWT, extracts user_id, fetches balance from chips-api
4. Server updates `ConnectedPlayer.account_total_cash`
5. Game can proceed once balance is loaded

### Balance Update Flow (after game):
1. Game ends → `state_end_step()` called
2. Server gets winner's `jwt_token` and `user_id` from `ConnectedPlayer`
3. Server calls `chips_api_service.update_chips(user_id, balance, jwt_token, callback)`
4. API updates balance, server logs result

## Security Improvements
- ✅ Server is authoritative source for all balance operations
- ✅ Server validates JWT tokens before making API calls
- ✅ Client cannot manipulate balance (only provides JWT)
- ✅ JWT tokens never sent to other clients (excluded from serialization)

## Testing Checklist
- [ ] Client sends JWT on connection
- [ ] Server extracts user_id from JWT
- [ ] Server fetches balance from chips-api
- [ ] Server handles 404 (user not found) by creating user with 0 balance
- [ ] Server disconnects player on balance fetch failure (no fallback)
- [ ] Balance updates work after game completion
- [ ] JWT token not serialized/sent to clients
- [ ] Multiple players can connect with different tokens
- [ ] Seat assignment works after balance is loaded

## Files to Modify
1. `poker-game/scripts/contracts/connected_player.gd` - Add jwt_token, user_id fields
2. `poker-game/scripts/utilities/jwt_utils.gd` - NEW: JWT decoding utilities
3. `poker-game/scripts/managers/server_manager.gd` - Add register_player_auth RPC, balance fetching
4. `poker-game/scripts/managers/chips_api_service.gd` - Accept jwt_token parameter
5. `poker-game/scripts/managers/client_manager.gd` - Send JWT on connection, remove balance fetching
6. `poker-game/scripts/managers/game_manager.gd` - Use stored JWT for balance updates

## Files to Remove Logic From (but keep file)
- None - all modifications are additions/replacements

---

**Estimated Complexity**: Medium
**Breaking Changes**: Yes - requires clients to send JWT on connection
**Backwards Compatible**: No - old clients without JWT will fail
**Security Impact**: High - significant security improvement

