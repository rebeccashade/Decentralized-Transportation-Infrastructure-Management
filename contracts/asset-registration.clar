;; Asset Registration Contract
;; Records transportation infrastructure assets

;; Error codes
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_ALREADY_REGISTERED u101)
(define-constant ERR_INVALID_DATA u102)

;; Data structures
(define-map assets
  { asset-id: (string-ascii 36) }
  {
    name: (string-ascii 100),
    asset-type: (string-ascii 50),
    location: (string-ascii 100),
    construction-date: uint,
    last-updated: uint,
    owner: principal
  }
)

(define-map asset-admins
  { admin: principal }
  { is-admin: bool }
)

;; Initial admin setup (contract deployer)
(define-data-var contract-owner principal tx-sender)

;; Read-only functions
(define-read-only (get-asset (asset-id (string-ascii 36)))
  (map-get? assets { asset-id: asset-id })
)

(define-read-only (is-admin (address principal))
  (default-to
    false
    (get is-admin (map-get? asset-admins { admin: address }))
  )
)

;; Public functions
(define-public (register-asset
    (asset-id (string-ascii 36))
    (name (string-ascii 100))
    (asset-type (string-ascii 50))
    (location (string-ascii 100))
    (construction-date uint))
  (let ((caller tx-sender))
    (asserts! (is-admin caller) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (get-asset asset-id)) (err ERR_ALREADY_REGISTERED))

    (map-set assets
      { asset-id: asset-id }
      {
        name: name,
        asset-type: asset-type,
        location: location,
        construction-date: construction-date,
        last-updated: (unwrap-panic (get-block-info? time u0)),
        owner: caller
      }
    )
    (ok asset-id)
  )
)

(define-public (update-asset
    (asset-id (string-ascii 36))
    (name (string-ascii 100))
    (asset-type (string-ascii 50))
    (location (string-ascii 100)))
  (let ((caller tx-sender)
        (asset (unwrap! (get-asset asset-id) (err ERR_INVALID_DATA))))
    (asserts! (or (is-admin caller) (is-eq (get owner asset) caller)) (err ERR_UNAUTHORIZED))

    (map-set assets
      { asset-id: asset-id }
      (merge asset {
        name: name,
        asset-type: asset-type,
        location: location,
        last-updated: (unwrap-panic (get-block-info? time u0))
      })
    )
    (ok asset-id)
  )
)

(define-public (add-admin (new-admin principal))
  (let ((caller tx-sender))
    (asserts! (or (is-eq caller (var-get contract-owner)) (is-admin caller)) (err ERR_UNAUTHORIZED))
    (map-set asset-admins { admin: new-admin } { is-admin: true })
    (ok new-admin)
  )
)

(define-public (remove-admin (admin principal))
  (let ((caller tx-sender))
    (asserts! (is-eq caller (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set asset-admins { admin: admin } { is-admin: false })
    (ok true)
  )
)
