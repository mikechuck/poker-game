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

    tags = { Name = "PokerAccounts" }
}

resource "aws_dynamodb_table" "games_table" {
    name           = "Games"
    billing_mode   = "PAY_PER_REQUEST"
    
    hash_key       = "gameId"
    range_key      = "hostPlayerId"

    attribute {
        name = "gameId"
        type = "S"
    }

    attribute {
        name = "hostPlayerId"
        type = "S"
    }

    attribute {
        name = "endTimeEpochMilliseconds"
        type = "N" 
    }

    tags = { Name = "PokerGames" }

    global_secondary_index {
        name               = "HostPlayerIdIndex"
        hash_key           = "hostPlayerId"       # Make the Host the search key here
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

    # GSIs are the ONLY place where you might see key_schema requirements 
    # depending on your provider version, but hash_key/range_key is safer here too:
    global_secondary_index {
        name            = "CreditorIndex"
        hash_key        = "creditorId"
        range_key       = "debterId"
        projection_type = "ALL"
    }

    tags = { Name = "PokerDebts" }
}
# --- End DynamoDB Config ---