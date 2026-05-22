# --- Start DynamoDB Config ---

resource "aws_dynamodb_table" "accounts_table" {
    name           = "Accounts"
    billing_mode   = "PAY_PER_REQUEST"
    
    # Use arguments for the main table keys
    hash_key       = "AccountId"
    range_key      = "PlayerName"

    attribute {
        name = "AccountId"
        type = "S"
    }

    attribute {
        name = "PlayerName"
        type = "S"
    }

    tags = { Name = "PokerAccounts" }
}

resource "aws_dynamodb_table" "games_table" {
    name           = "Games"
    billing_mode   = "PAY_PER_REQUEST"
    
    hash_key       = "GameId"
    range_key      = "HostPlayerId"

    attribute {
        name = "GameId"
        type = "S"
    }

    attribute {
        name = "HostPlayerId"
        type = "S"
    }

    attribute {
        name = "EndTimeEpochMilliseconds"
        type = "N" 
    }

    tags = { Name = "PokerGames" }

    global_secondary_index {
        name               = "HostPlayerIdIndex"
        hash_key           = "HostPlayerId"       # Make the Host the search key here
        projection_type    = "ALL"      # Copies all game details into the index view
        range_key          = "EndTimeEpochMilliseconds"
    }
}

resource "aws_dynamodb_table" "debts_table" {
    name           = "Debts"
    billing_mode   = "PAY_PER_REQUEST"
    
    hash_key       = "debter_id"
    range_key      = "creditor_id"

    attribute {
        name = "debter_id"
        type = "S"
    }

    attribute {
        name = "creditor_id"
        type = "S"
    }

    # GSIs are the ONLY place where you might see key_schema requirements 
    # depending on your provider version, but hash_key/range_key is safer here too:
    global_secondary_index {
        name            = "CreditorIndex"
        hash_key        = "creditor_id"
        range_key       = "debter_id"
        projection_type = "ALL"
    }

    tags = { Name = "PokerDebts" }
}
# --- End DynamoDB Config ---