# --- Start DynamoDB Config ---

resource "aws_dynamodb_table" "accounts_table" {
    name           = "Accounts"
    billing_mode   = "PAY_PER_REQUEST"
    
    # Use arguments for the main table keys
    hash_key       = "accountId"
    range_key      = "playerName"

    attribute {
        name = "accountId"
        type = "S"
    }

    attribute {
        name = "playerName"
        type = "S"
    }

    attribute {
        name = "friendCode"
        type = "S"
    }

    tags = { Name = "PokerAccounts" }

    global_secondary_index {
        name               = "FriendCodeIndex"
        hash_key           = "friendCode"
        projection_type    = "ALL"
    }
}

resource "aws_dynamodb_table" "games_table" {
    name           = "Games"
    billing_mode   = "PAY_PER_REQUEST"
    
    hash_key       = "gameId"
    range_key      = "hostAccountId"

    attribute {
        name = "gameId"
        type = "S"
    }

    attribute {
        name = "hostAccountId"
        type = "S"
    }

    attribute {
        name = "endTimeEpochMilliseconds"
        type = "N" 
    }

    tags = { Name = "PokerGames" }

    global_secondary_index {
        name               = "HostAccountIdIndex"
        hash_key           = "hostAccountId"
        projection_type    = "ALL"      # Copies all game details into the index view
        range_key          = "endTimeEpochMilliseconds"
    }
}

resource "aws_dynamodb_table" "debts_table" {
    name           = "Debts"
    billing_mode   = "PAY_PER_REQUEST"
    
    hash_key       = "debterId"
    range_key      = "creditorId"

    attribute {
        name = "debterId"
        type = "S"
    }

    attribute {
        name = "creditorId"
        type = "S"
    }

    global_secondary_index {
        name            = "CreditorIndex"
        hash_key        = "creditorId"
        range_key       = "debterId"
        projection_type = "ALL"
    }

    tags = { Name = "PokerDebts" }
}

resource "aws_dynamodb_table" "join_tokens_table" {
    name        = "JoinTokens"
    billing_mode   = "PAY_PER_REQUEST"
    
    hash_key       = "accountId"

    attribute {
        name = "accountId"
        type = "S"
    }

    attribute {
        name = "gameId"
        type = "S"
    }

    global_secondary_index {
        name            = "GameIdIndex"
        hash_key        = "gameId"
        range_key       = "accountId"
        projection_type = "ALL"
    }

    tags = { Name = "PokerJoinTokens" }
}

resource "aws_dynamodb_table" "relationships_table" {
    name = "Relationships"
    billing_mode   = "PAY_PER_REQUEST"
    
    hash_key       = "accountId"
    range_key      = "peerAccountId"

    attribute {
        name = "accountId"
        type = "S"
    }

    attribute {
        name = "peerAccountId"
        type = "S"
    }

    global_secondary_index {
        name            = "PeerAccountIdIndex"
        hash_key        = "peerAccountId"
        range_key       = "accountId"
        projection_type = "ALL"
    }
}

# --- End DynamoDB Config ---