;; Condition Monitoring Contract
;; Tracks physical state of infrastructure assets

;; Error codes
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INVALID_ASSET u101)
(define-constant ERR_INVALID_CONDITION u102)

;; Condition status types
(define-constant CONDITION_EXCELLENT u5)
(define-constant CONDITION_GOOD u4)
(define-constant CONDITION_FAIR u3)
(define-constant CONDITION_POOR u2)
(define-constant CONDITION_CRITICAL u1)

;; Data structures
(define-map asset-conditions
  { asset-id: (string-ascii 36) }
  {
    condition-rating: uint,
    inspection-date: uint,
    inspector: principal,
    notes: (string-utf8 500),
    issues: (list 10 (string-utf8 100))
  }
)

(define-map condition-inspectors
  { inspector: principal }
  { is-inspector: bool }
)

;; Initial admin setup
(define-data-var contract-owner principal tx-sender)

;; Read-only functions
(define-read-only (get-asset-condition (asset-id (string-ascii 36)))
  (map-get? asset-conditions { asset-id: asset-id })
)

(define-read-only (is-inspector (address principal))
  (default-to
    false
    (get is-inspector (map-get? condition-inspectors { inspector: address }))
  )
)

(define-read-only (is-valid-condition (condition uint))
  (and (<= CONDITION_CRITICAL condition) (<= condition CONDITION_EXCELLENT))
)

;; Public functions
(define-public (record-condition
    (asset-id (string-ascii 36))
    (condition-rating uint)
    (notes (string-utf8 500))
    (issues (list 10 (string-utf8 100))))
  (let ((caller tx-sender))
    (asserts! (is-inspector caller) (err ERR_UNAUTHORIZED))
    (asserts! (is-valid-condition condition-rating) (err ERR_INVALID_CONDITION))

    (map-set asset-conditions
      { asset-id: asset-id }
      {
        condition-rating: condition-rating,
        inspection-date: (unwrap-panic (get-block-info? time u0)),
        inspector: caller,
        notes: notes,
        issues: issues
      }
    )
    (ok asset-id)
  )
)

(define-public (add-inspector (new-inspector principal))
  (let ((caller tx-sender))
    (asserts! (is-eq caller (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set condition-inspectors { inspector: new-inspector } { is-inspector: true })
    (ok new-inspector)
  )
)

(define-public (remove-inspector (inspector principal))
  (let ((caller tx-sender))
    (asserts! (is-eq caller (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set condition-inspectors { inspector: inspector } { is-inspector: false })
    (ok true)
  )
)
