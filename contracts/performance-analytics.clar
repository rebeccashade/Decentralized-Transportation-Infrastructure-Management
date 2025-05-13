;; Performance Analytics Contract
;; Monitors infrastructure reliability and performance metrics

;; Error codes
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INVALID_ASSET u101)
(define-constant ERR_INVALID_DATA u102)

;; Data structures
(define-map asset-performance
  { asset-id: (string-ascii 36) }
  {
    total-downtime: uint,
    last-failure: (optional uint),
    maintenance-count: uint,
    avg-repair-time: uint,
    reliability-score: uint,
    last-updated: uint
  }
)

(define-map incident-reports
  { incident-id: (string-ascii 36) }
  {
    asset-id: (string-ascii 36),
    start-time: uint,
    end-time: (optional uint),
    severity: uint,
    description: (string-utf8 500),
    reported-by: principal,
    created-at: uint
  }
)

(define-map data-reporters
  { reporter: principal }
  { is-reporter: bool }
)

;; Initial admin setup
(define-data-var contract-owner principal tx-sender)

;; Read-only functions
(define-read-only (get-asset-performance (asset-id (string-ascii 36)))
  (map-get? asset-performance { asset-id: asset-id })
)

(define-read-only (get-incident (incident-id (string-ascii 36)))
  (map-get? incident-reports { incident-id: incident-id })
)

(define-read-only (is-reporter (address principal))
  (default-to
    false
    (get is-reporter (map-get? data-reporters { reporter: address }))
  )
)

;; Public functions
(define-public (report-incident
    (incident-id (string-ascii 36))
    (asset-id (string-ascii 36))
    (start-time uint)
    (severity uint)
    (description (string-utf8 500)))
  (let ((caller tx-sender))
    (asserts! (is-reporter caller) (err ERR_UNAUTHORIZED))
    (asserts! (and (>= severity u1) (<= severity u5)) (err ERR_INVALID_DATA))

    (map-set incident-reports
      { incident-id: incident-id }
      {
        asset-id: asset-id,
        start-time: start-time,
        end-time: none,
        severity: severity,
        description: description,
        reported-by: caller,
        created-at: (unwrap-panic (get-block-info? time u0))
      }
    )
    (ok incident-id)
  )
)

(define-public (resolve-incident
    (incident-id (string-ascii 36))
    (end-time uint))
  (let ((caller tx-sender)
        (incident (unwrap! (get-incident incident-id) (err ERR_INVALID_DATA))))
    (asserts!
      (or
        (is-eq caller (get reported-by incident))
        (is-reporter caller)
      )
      (err ERR_UNAUTHORIZED))

    ;; Update the incident
    (map-set incident-reports
      { incident-id: incident-id }
      (merge incident { end-time: (some end-time) })
    )

    ;; Update asset performance metrics
    (let ((asset-id (get asset-id incident))
          (downtime (- end-time (get start-time incident)))
          (performance (default-to
            {
              total-downtime: u0,
              last-failure: none,
              maintenance-count: u0,
              avg-repair-time: u0,
              reliability-score: u100,
              last-updated: u0
            }
            (get-asset-performance asset-id))))

      (map-set asset-performance
        { asset-id: asset-id }
        (merge performance {
          total-downtime: (+ (get total-downtime performance) downtime),
          last-failure: (some (get start-time incident)),
          last-updated: (unwrap-panic (get-block-info? time u0))
        })
      )
      (ok incident-id)
    )
  )
)

(define-public (update-asset-metrics
    (asset-id (string-ascii 36))
    (maintenance-count uint)
    (avg-repair-time uint)
    (reliability-score uint))
  (let ((caller tx-sender)
        (performance (default-to
          {
            total-downtime: u0,
            last-failure: none,
            maintenance-count: u0,
            avg-repair-time: u0,
            reliability-score: u100,
            last-updated: u0
          }
          (get-asset-performance asset-id))))
    (asserts! (is-reporter caller) (err ERR_UNAUTHORIZED))
    (asserts! (and (>= reliability-score u0) (<= reliability-score u100)) (err ERR_INVALID_DATA))

    (map-set asset-performance
      { asset-id: asset-id }
      (merge performance {
        maintenance-count: maintenance-count,
        avg-repair-time: avg-repair-time,
        reliability-score: reliability-score,
        last-updated: (unwrap-panic (get-block-info? time u0))
      })
    )
    (ok asset-id)
  )
)

(define-public (add-reporter (new-reporter principal))
  (let ((caller tx-sender))
    (asserts! (is-eq caller (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set data-reporters { reporter: new-reporter } { is-reporter: true })
    (ok new-reporter)
  )
)

(define-public (remove-reporter (reporter principal))
  (let ((caller tx-sender))
    (asserts! (is-eq caller (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set data-reporters { reporter: reporter } { is-reporter: false })
    (ok true)
  )
)
