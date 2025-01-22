# Metalink NFT Marketplace Contract

A comprehensive smart contract for managing NFT minting, trading, and marketplace operations on the Stacks blockchain.

## Features

- NFT minting with customizable royalties
- Marketplace listing and trading
- Cross-chain NFT bridging
- Metadata management
- Batch operations support
- Address blacklisting
- Referral program with rewards
- Performance analytics

## Core Functions

### Minting and Trading
- `mint-nft`: Create new NFTs with royalty settings and metadata
- `batch-mint-nft`: Mint multiple NFTs in one transaction
- `list-nft`: List NFTs for sale with specified price
- `buy-nft`: Purchase listed NFTs with automatic fee distribution

### Marketplace Management
- `bridge-nft`: Import NFTs from other chains
- `update-metadata`: Modify NFT metadata
- `add-to-blacklist`: Block addresses from marketplace participation
- `remove-from-blacklist`: Remove addresses from blacklist

### Query Functions
- `get-metadata`: Retrieve NFT metadata
- `get-nft-info`: Get comprehensive NFT information
- `get-trade-history`: View NFT trading history
- `get-performance-metrics`: Access marketplace statistics
- `get-referral-info`: Check referral program details

## Fee Structure

- Marketplace Fee: 5%
- Referral Reward: 1%
- Creator Royalties: Up to 20%

## Data Models

### NFT Metadata
```clarity
{
  name: string-ascii,
  description: string-ascii,
  image-url: string-ascii,
  attributes: list of traits
}
```

### Market Listing
```clarity
{
  price: uint,
  seller: principal,
  listed: bool
}
```

## Error Codes

- `ERR-NOT-AUTHORIZED (u1)`: Unauthorized access
- `ERR-INSUFFICIENT-BALANCE (u2)`: Insufficient funds
- `ERR-INVALID-ROYALTY (u3)`: Invalid royalty rate
- `ERR-NFT-NOT-FOUND (u4)`: NFT doesn't exist
- Additional error codes for various validation checks

## Security Features

- Owner-only administrative functions
- Balance verification for purchases
- Blacklist system for bad actors
- Input validation for all operations

## Cross-Chain Support

Currently supports bridging from:
- Ethereum
- Solana