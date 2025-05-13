;; Maintenance Scheduling Contract
;; Manages repair planning for infrastructure assets

;; Error codes
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INVALID_ASSET u101)
(define-constant ERR_INVALID_SCHEDULE u102)
(define-constant ERR_ALREADY_SCHEDULED u103)

;; Task priority levels
(define-constant PRIORITY_EMERGENCY u1)
(define-constant PRIORITY_HIGH u2)
(define-constant PRIORITY_MEDIUM u3)
(define-constant PRIORITY_LOW u4)
(define-constant PRIORITY_ROUTINE u5)

;; Task status
(define-constant STATUS_PLANNED u1)
(define-constant STATUS_SCHEDULED u2)
(define-constant STATUS_IN_PROGRESS u3)
(define-constant STATUS_COMPLETED u4)
(define-constant STATUS_CANCELED u5)

;; Data structures
(define-map maintenance-tasks
  { task-id: (string-ascii 36) }
  {
    asset-id: (string-ascii 36),
    description: (string-utf8 500),
    priority: uint,
    status: uint,
    scheduled-date: uint,
    estimated-duration: uint,
    created-by: principal,
    assigned-to: (optional principal),
    created-at: uint
  }
)

(define-map maintenance-planners
  { planner: principal }
  { is-planner: bool }
)

;; Initial admin setup
(define-data-var contract-owner principal tx-sender)

;; Read-only functions
(define-read-only (get-maintenance-task (task-id (string-ascii 36)))
  (map-get? maintenance-tasks { task-id: task-id })
)

(define-read-only (is-planner (address principal))
  (default-to
    false
    (get is-planner (map-get? maintenance-planners { planner: address }))
  )
)

;; Public functions
(define-public (create-maintenance-task
    (task-id (string-ascii 36))
    (asset-id (string-ascii 36))
    (description (string-utf8 500))
    (priority uint)
    (scheduled-date uint)
    (estimated-duration uint))
  (let ((caller tx-sender))
    (asserts! (is-planner caller) (err ERR_UNAUTHORIZED))
    (asserts! (and (>= priority PRIORITY_EMERGENCY) (<= priority PRIORITY_ROUTINE)) (err ERR_INVALID_SCHEDULE))
    (asserts! (is-none (get-maintenance-task task-id)) (err ERR_ALREADY_SCHEDULED))

    (map-set maintenance-tasks
      { task-id: task-id }
      {
        asset-id: asset-id,
        description: description,
        priority: priority,
        status: STATUS_PLANNED,
        scheduled-date: scheduled-date,
        estimated-duration: estimated-duration,
        created-by: caller,
        assigned-to: none,
        created-at: (unwrap-panic (get-block-info? time u0))
      }
    )
    (ok task-id)
  )
)

(define-public (update-task-status
    (task-id (string-ascii 36))
    (new-status uint))
  (let ((caller tx-sender)
        (task (unwrap! (get-maintenance-task task-id) (err ERR_INVALID_ASSET))))
    (asserts!
      (or
        (is-planner caller)
        (is-some (get assigned-to task))
      )
      (err ERR_UNAUTHORIZED))
    (asserts! (and (>= new-status STATUS_PLANNED) (<= new-status STATUS_CANCELED)) (err ERR_INVALID_SCHEDULE))

    (map-set maintenance-tasks
      { task-id: task-id }
      (merge task { status: new-status })
    )
    (ok task-id)
  )
)

(define-public (assign-task
    (task-id (string-ascii 36))
    (assignee principal))
  (let ((caller tx-sender)
        (task (unwrap! (get-maintenance-task task-id) (err ERR_INVALID_ASSET))))
    (asserts! (is-planner caller) (err ERR_UNAUTHORIZED))

    (map-set maintenance-tasks
      { task-id: task-id }
      (merge task {
        assigned-to: (some assignee),
        status: STATUS_SCHEDULED
      })
    )
    (ok task-id)
  )
)

(define-public (add-planner (new-planner principal))
  (let ((caller tx-sender))
    (asserts! (is-eq caller (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set maintenance-planners { planner: new-planner } { is-planner: true })
    (ok new-planner)
  )
)

(define-public (remove-planner (planner principal))
  (let ((caller tx-sender))
    (asserts! (is-eq caller (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set maintenance-planners { planner: planner } { is-planner: false })
    (ok true)
  )
)
