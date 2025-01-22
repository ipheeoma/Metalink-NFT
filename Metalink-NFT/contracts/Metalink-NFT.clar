;; Metalink-NFT Marketplace Contract
;; Supports NFT minting, trading, royalty mechanisms, batch operations, blacklisting, and referral program
;; Extended with cross-chain support, metadata standardization, and analytics

;; Constants and Error Codes
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MARKETPLACE-FEE-RATE u5)  ;; 5% marketplace fee
(define-constant REFERRAL-REWARD-RATE u1)  ;; 1% referral reward

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2))
(define-constant ERR-INVALID-ROYALTY (err u3))
(define-constant ERR-NFT-NOT-FOUND (err u4))
(define-constant ERR-INVALID-NFT-ID (err u5))
(define-constant ERR-INVALID-PRICE (err u6))
(define-constant ERR-ALREADY-LISTED (err u7))
(define-constant ERR-INVALID-CHAIN (err u8))
(define-constant ERR-INVALID-METADATA (err u9))
(define-constant ERR-NOT-LISTED (err u10))
(define-constant ERR-INVALID-EXTERNAL-ID (err u11))
(define-constant ERR-BLACKLISTED (err u12))
(define-constant ERR-INVALID-REFERRER (err u13))
(define-constant ERR-CANNOT-BLACKLIST-OWNER (err u14))
(define-constant ERR-NOT-BLACKLISTED (err u15))
(define-constant ERR-INVALID-ADDRESS (err u16))

;; NFT Definition
(define-non-fungible-token nft-marketplace uint)

;; Royalty tracking map
(define-map nft-royalties 
  { nft-id: uint }
  {
    creator: principal,
    royalty-rate: uint
  }
)

;; Market listing map
(define-map market-listings
  { nft-id: uint }
  {
    price: uint,
    seller: principal,
    listed: bool
  }
)

;; Cross-chain NFT map
(define-map cross-chain-nfts
  { chain: (string-ascii 20), external-id: (string-ascii 50) }
  { nft-id: uint }
)

;; Metadata map
(define-map nft-metadata
  { nft-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    image-url: (string-ascii 200),
    attributes: (list 20 {trait: (string-ascii 50), value: (string-ascii 50)})
  }
)

;; Trade history map
(define-map trade-history
  { nft-id: uint }
  (list 50 {
    seller: principal,
    buyer: principal,
    price: uint
  })
)

;; Blacklist map
(define-map blacklist
  { address: principal }
  { blacklisted: bool }
)

;; Referral program map
(define-map referrals
  { user: principal }
  { referrer: principal }
)

;; Referral rewards map
(define-map referral-rewards
  { user: principal }
  { total-reward: uint }
)

;; Performance metrics
(define-data-var total-volume uint u0)
(define-data-var total-royalties uint u0)
(define-data-var total-marketplace-fees uint u0)

;; Helper function to validate ownership
(define-private (is-owner (nft-id uint))
  (match (nft-get-owner? nft-marketplace nft-id)
    owner (is-eq tx-sender owner)
    false
  )
)

;; Helper function to validate chain
(define-private (is-valid-chain (chain (string-ascii 20)))
  (or
    (is-eq chain "ethereum")
    (is-eq chain "solana")
  )
)

;; Helper function to validate NFT ID
(define-private (is-valid-nft-id (nft-id uint))
  (and 
    (> nft-id u0)
    (< nft-id u1000000)  ;; Assuming a maximum of 1 million NFTs
  )
)

;; Helper function to validate metadata
(define-private (is-valid-metadata (metadata (tuple (name (string-ascii 100)) (description (string-ascii 500)) (image-url (string-ascii 200)) (attributes (list 20 (tuple (trait (string-ascii 50)) (value (string-ascii 50))))))))
  (and
    (> (len (get name metadata)) u0)
    (> (len (get description metadata)) u0)
    (> (len (get image-url metadata)) u0)
  )
)

;; Helper function to validate external ID
(define-private (is-valid-external-id (external-id (string-ascii 50)))
  (and
    (> (len external-id) u0)
    (<= (len external-id) u50)
  )
)

;; Helper function to check if an address is blacklisted
(define-private (is-blacklisted (address principal))
  (default-to false (get blacklisted (map-get? blacklist { address: address })))
)

;; Helper function to validate address
(define-private (is-valid-address (address principal))
  (not (is-eq address CONTRACT-OWNER))
)

;; Mint a new NFT with royalty settings and metadata
(define-public (mint-nft 
  (nft-id uint) 
  (royalty-rate uint)
  (metadata (tuple (name (string-ascii 100)) (description (string-ascii 500)) (image-url (string-ascii 200)) (attributes (list 20 (tuple (trait (string-ascii 50)) (value (string-ascii 50)))))))
)
  (begin
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    (asserts! (<= royalty-rate u20) ERR-INVALID-ROYALTY)
    (asserts! (is-valid-metadata metadata) ERR-INVALID-METADATA)
    (try! (nft-mint? nft-marketplace nft-id tx-sender))
    (map-set nft-royalties 
      { nft-id: nft-id }
      {
        creator: tx-sender,
        royalty-rate: royalty-rate
      }
    )
    (map-set nft-metadata
      { nft-id: nft-id }
      metadata
    )
    (ok nft-id)
  )
)

;; Batch mint NFTs
(define-public (batch-mint-nft 
  (nft-ids (list 20 uint))
  (royalty-rates (list 20 uint))
  (metadata-list (list 20 (tuple (name (string-ascii 100)) (description (string-ascii 500)) (image-url (string-ascii 200)) (attributes (list 20 (tuple (trait (string-ascii 50)) (value (string-ascii 50))))))))
)
  (begin
    (asserts! (is-eq (len nft-ids) (len royalty-rates)) ERR-INVALID-NFT-ID)
    (asserts! (is-eq (len nft-ids) (len metadata-list)) ERR-INVALID-NFT-ID)
    (ok (map mint-nft nft-ids royalty-rates metadata-list))
  )
)

;; List NFT for sale
(define-public (list-nft 
  (nft-id uint)
  (price uint)
)
  (begin
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    (asserts! (is-owner nft-id) ERR-NOT-AUTHORIZED)
    (asserts! (> price u0) ERR-INVALID-PRICE)
    (match (map-get? market-listings { nft-id: nft-id })
      listing (asserts! (not (get listed listing)) ERR-ALREADY-LISTED)
      true
    )
    (map-set market-listings 
      { nft-id: nft-id }
      {
        price: price,
        seller: tx-sender,
        listed: true
      }
    )
    (ok true)
  )
)

;; Batch list NFTs
(define-public (batch-list-nft
  (nft-ids (list 20 uint))
  (prices (list 20 uint))
)
  (begin
    (asserts! (is-eq (len nft-ids) (len prices)) ERR-INVALID-NFT-ID)
    (ok (map list-nft nft-ids prices))
  )
)

;; Remove NFT listing
(define-public (delist-nft 
  (nft-id uint)
)
  (begin
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    (asserts! (is-owner nft-id) ERR-NOT-AUTHORIZED)
    
    (match (map-get? market-listings { nft-id: nft-id })
      listing 
        (if (get listed listing)
          (begin
            (map-set market-listings 
              { nft-id: nft-id }
              {
                price: u0,
                seller: tx-sender,
                listed: false
              }
            )
            (ok true))
          ERR-NOT-LISTED)
      ERR-NFT-NOT-FOUND)
  )
)

;; Purchase an NFT
(define-public (buy-nft 
  (nft-id uint)
  (referrer (optional principal))
)
  (begin
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    (asserts! (not (is-blacklisted tx-sender)) ERR-BLACKLISTED)
    (match (nft-get-owner? nft-marketplace nft-id)
      current-owner 
        (match (map-get? market-listings { nft-id: nft-id })
          listing
            (match (map-get? nft-royalties { nft-id: nft-id })
              royalty-info
                (begin
                  (asserts! (get listed listing) ERR-NOT-LISTED)
                  (asserts! (>= (stx-get-balance tx-sender) (get price listing)) ERR-INSUFFICIENT-BALANCE)
                  
                  (try! (stx-transfer? 
                    (/ (* (get price listing) MARKETPLACE-FEE-RATE) u100) 
                    tx-sender 
                    CONTRACT-OWNER))
                  
                  (try! (stx-transfer? 
                    (/ (* (get price listing) (get royalty-rate royalty-info)) u100)
                    tx-sender 
                    (get creator royalty-info)))
                  
                  ;; Handle referral reward
                  (match referrer
                    ref 
                      (begin
                        (asserts! (not (is-eq ref tx-sender)) ERR-INVALID-REFERRER)
                        (try! (stx-transfer?
                          (/ (* (get price listing) REFERRAL-REWARD-RATE) u100)
                          tx-sender
                          ref))
                        (map-set referrals { user: tx-sender } { referrer: ref })
                        (map-set referral-rewards { user: ref }
                          { total-reward: (+ (default-to u0 (get total-reward (map-get? referral-rewards { user: ref })))
                                             (/ (* (get price listing) REFERRAL-REWARD-RATE) u100)) }))
                    true)
                  
                  (try! (stx-transfer? 
                    (- (get price listing) 
                       (+ (/ (* (get price listing) MARKETPLACE-FEE-RATE) u100)
                          (/ (* (get price listing) (get royalty-rate royalty-info)) u100)
                          (/ (* (get price listing) REFERRAL-REWARD-RATE) u100)))
                    tx-sender 
                    current-owner))
                  
                  (try! (nft-transfer? nft-marketplace nft-id current-owner tx-sender))
                  
                  (map-set market-listings 
                    { nft-id: nft-id }
                    {
                      price: u0,
                      seller: tx-sender,
                      listed: false
                    }
                  )
                  
                  (var-set total-volume (+ (var-get total-volume) (get price listing)))
                  (var-set total-royalties (+ (var-get total-royalties) (/ (* (get price listing) (get royalty-rate royalty-info)) u100)))
                  (var-set total-marketplace-fees (+ (var-get total-marketplace-fees) (/ (* (get price listing) MARKETPLACE-FEE-RATE) u100)))
                  
                  (ok true)
                )
              ERR-NFT-NOT-FOUND)
          ERR-NFT-NOT-FOUND)
      ERR-NFT-NOT-FOUND)
  )
)

;; Bridge NFT from another chain
(define-public (bridge-nft 
  (chain (string-ascii 20))
  (external-id (string-ascii 50))
  (nft-id uint)
  (metadata (tuple (name (string-ascii 100)) (description (string-ascii 500)) (image-url (string-ascii 200)) (attributes (list 20 (tuple (trait (string-ascii 50)) (value (string-ascii 50)))))))
)
  (begin
    (asserts! (is-valid-chain chain) ERR-INVALID-CHAIN)
    (asserts! (is-valid-external-id external-id) ERR-INVALID-EXTERNAL-ID)
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    (asserts! (is-valid-metadata metadata) ERR-INVALID-METADATA)
    
    (try! (nft-mint? nft-marketplace nft-id tx-sender))
    
    (map-set cross-chain-nfts
      { chain: chain, external-id: external-id }
      { nft-id: nft-id }
    )
    
    (map-set nft-metadata
      { nft-id: nft-id }
      metadata
    )
    
    (ok nft-id)
  )
)

;; Update NFT metadata
(define-public (update-metadata
  (nft-id uint)
  (metadata (tuple (name (string-ascii 100)) (description (string-ascii 500)) (image-url (string-ascii 200)) (attributes (list 20 (tuple (trait (string-ascii 50)) (value (string-ascii 50)))))))
)
  (begin
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    (asserts! (is-owner nft-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-metadata metadata) ERR-INVALID-METADATA)
    
    (map-set nft-metadata
      { nft-id: nft-id }
      metadata
    )
    
    (ok true)
  )
)

;; Add address to blacklist
(define-public (add-to-blacklist (address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq address CONTRACT-OWNER)) ERR-CANNOT-BLACKLIST-OWNER)
    (ok (map-set blacklist { address: address } { blacklisted: true }))
  )
)

;; Remove address from blacklist
(define-public (remove-from-blacklist (address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-address address) ERR-INVALID-ADDRESS)
    (match (map-get? blacklist { address: address })
      entry (begin
        (asserts! (get blacklisted entry) ERR-NOT-BLACKLISTED)
        (ok (map-delete blacklist { address: address }))
      )
      ERR-NOT-BLACKLISTED
    )
  )
)

;; Get NFT metadata
(define-read-only (get-metadata (nft-id uint))
  (begin
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    (ok (map-get? nft-metadata { nft-id: nft-id }))
  )
)

;; Get NFT information
(define-read-only (get-nft-info (nft-id uint))
  (begin
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    (ok {
      owner: (nft-get-owner? nft-marketplace nft-id),
      listing: (map-get? market-listings { nft-id: nft-id }),
      royalties: (map-get? nft-royalties { nft-id: nft-id }),
      metadata: (map-get? nft-metadata { nft-id: nft-id })
    })
  )
)

;; Get trade history for an NFT
(define-read-only (get-trade-history (nft-id uint))
  (begin
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    (ok (map-get? trade-history { nft-id: nft-id }))
  )
)

;; Get performance metrics
(define-read-only (get-performance-metrics)
  (ok {
    total-volume: (var-get total-volume),
    total-royalties: (var-get total-royalties),
    total-marketplace-fees: (var-get total-marketplace-fees)
  })
)

;; Get referral information
(define-read-only (get-referral-info (user principal))
  (ok {
    referrer: (get referrer (map-get? referrals { user: user })),
    total-reward: (get total-reward (map-get? referral-rewards { user: user }))
  })
)

