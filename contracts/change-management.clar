;; Change Management Contract
;; Manages transformation changes and approvals

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u4000))
(define-constant err-change-not-found (err u4001))
(define-constant err-invalid-status (err u4002))

;; Data Maps
(define-map change-requests
  { change-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    requester: principal,
    process-id: uint,
    status: (string-ascii 20),
    priority: (string-ascii 10),
    impact-level: (string-ascii 10),
    created-at: uint,
    approved-at: (optional uint),
    implemented-at: (optional uint)
  }
)

(define-map change-approvals
  { change-id: uint, approver: principal }
  {
    approved: bool,
    approved-at: uint,
    comments: (string-ascii 300)
  }
)

;; Data Variables
(define-data-var next-change-id uint u1)
(define-data-var total-changes uint u0)

;; Public Functions

;; Create a new change request
(define-public (create-change-request
  (title (string-ascii 100))
  (description (string-ascii 500))
  (process-id uint)
  (priority (string-ascii 10))
  (impact-level (string-ascii 10)))
  (begin
    (let ((change-id (var-get next-change-id)))

      (map-set change-requests { change-id: change-id }
        {
          title: title,
          description: description,
          requester: tx-sender,
          process-id: process-id,
          status: "pending",
          priority: priority,
          impact-level: impact-level,
          created-at: block-height,
          approved-at: none,
          implemented-at: none
        }
      )

      (var-set next-change-id (+ change-id u1))
      (var-set total-changes (+ (var-get total-changes) u1))
      (ok change-id)
    )
  )
)

;; Approve a change request
(define-public (approve-change
  (change-id uint)
  (comments (string-ascii 300)))
  (begin
    (asserts! (is-some (map-get? change-requests { change-id: change-id })) err-change-not-found)

    (map-set change-approvals { change-id: change-id, approver: tx-sender }
      {
        approved: true,
        approved-at: block-height,
        comments: comments
      }
    )

    ;; Update change request status
    (let ((change-data (unwrap-panic (map-get? change-requests { change-id: change-id }))))
      (map-set change-requests { change-id: change-id }
        (merge change-data
          { status: "approved", approved-at: (some block-height) }
        )
      )
    )
    (ok true)
  )
)

;; Implement a change
(define-public (implement-change (change-id uint))
  (begin
    (let ((change-data (unwrap! (map-get? change-requests { change-id: change-id }) err-change-not-found)))
      (asserts! (is-eq (get status change-data) "approved") err-invalid-status)
      (asserts! (is-eq tx-sender (get requester change-data)) err-not-authorized)

      (map-set change-requests { change-id: change-id }
        (merge change-data
          { status: "implemented", implemented-at: (some block-height) }
        )
      )
      (ok true)
    )
  )
)

;; Read-only Functions

;; Get change request details
(define-read-only (get-change-request (change-id uint))
  (map-get? change-requests { change-id: change-id })
)

;; Get change approval
(define-read-only (get-change-approval (change-id uint) (approver principal))
  (map-get? change-approvals { change-id: change-id, approver: approver })
)

;; Get total changes
(define-read-only (get-total-changes)
  (var-get total-changes)
)
