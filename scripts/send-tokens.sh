#!/bin/bash

# Source the environment variables from the .env file
if [ -f .env ]; then
  source .env
else
  echo ".env file not found! Please create it with the necessary variables."
  exit 1
fi

# Use account1 identity
dfx identity use $ACCOUNT1

# Mint tokens
dfx canister call fakebob mint_tokens

# Transfer tokens to the stored principal
dfx canister call fakebob icrc1_transfer "(record {
    to = record { 
        owner = principal \"$PLUG_PRINCIPAL\"; 
        subaccount = null 
    }; 
    fee = opt 1_000_000; 
    memo = opt blob \"\"; 
    amount = 1_900_000_000
})"

# Mint tokens
dfx canister call fakebob mint_tokens

# Transfer tokens to the stored principal
dfx canister call fakebob icrc1_transfer "(record {
    to = record { 
        owner = principal \"$INTERNET_IDENTITY_PRINCIPAL\"; 
        subaccount = null 
    }; 
    fee = opt 1_000_000; 
    memo = opt blob \"\"; 
    amount = 1_800_000_000
})"

# Mint tokens
dfx canister call fakebob mint_tokens

# Transfer tokens to the stored principal
dfx canister call fakebob icrc1_transfer "(record {
    to = record { 
        owner = principal \"$INTERNET_IDENTITY_PRINCIPAL2\"; 
        subaccount = null 
    }; 
    fee = opt 1_000_000; 
    memo = opt blob \"\"; 
    amount = 1_800_000_000
})"

# Switch to account2 identity
dfx identity use $ACCOUNT2
