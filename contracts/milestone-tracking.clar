;; Milestone Tracking Contract
;; Monitors progress against grant objectives

(define-data-var admin principal tx-sender)

;; Milestone status enum: 0=Not Started, 1=In Progress, 2=Completed, 3=Verified
(define-constant STATUS-NOT-STARTED u0)
(define-constant STATUS-IN-PROGRESS u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-VERIFIED u3)

;; Map to store milestones by applicant and milestone ID
(define-map milestones
  { applicant: principal, milestone-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    deadline: uint,
    status: uint,
    funds-linked: uint
  }
)

;; Map to track milestone count per applicant
(define-map milestone-count principal uint)

;; Map to track verified applicants (simplified approach)
(define-map verified-applicants principal bool)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Check if applicant is verified
(define-private (is-verified (applicant principal))
  (default-to false (map-get? verified-applicants applicant))
)

;; Verify an applicant (admin only)
(define-public (verify-applicant (applicant principal))
  (begin
    (asserts! (is-admin) (err u403))
    (map-set verified-applicants applicant true)
    (ok true)
  )
)

;; Add a milestone for an applicant (admin only)
(define-public (add-milestone
  (applicant principal)
  (title (string-ascii 100))
  (description (string-ascii 500))
  (deadline uint)
  (funds-linked uint)
)
  (let (
    (current-count (default-to u0 (map-get? milestone-count applicant)))
    (new-count (+ current-count u1))
  )
    (asserts! (is-admin) (err u403))
    (asserts! (is-verified applicant) (err u401))

    (map-set milestones
      { applicant: applicant, milestone-id: new-count }
      {
        title: title,
        description: description,
        deadline: deadline,
        status: STATUS-NOT-STARTED,
        funds-linked: funds-linked
      }
    )
    (map-set milestone-count applicant new-count)
    (ok new-count)
  )
)

;; Update milestone status (applicant can mark in progress or completed)
(define-public (update-milestone-status (milestone-id uint) (new-status uint))
  (let (
    (milestone-key { applicant: tx-sender, milestone-id: milestone-id })
    (milestone-data (unwrap! (map-get? milestones milestone-key) (err u404)))
  )
    (asserts! (is-verified tx-sender) (err u401))
    (asserts! (is-eq (get status milestone-data) STATUS-NOT-STARTED) (err u402))
    (asserts! (or (is-eq new-status STATUS-IN-PROGRESS) (is-eq new-status STATUS-COMPLETED)) (err u403))

    (map-set milestones
      milestone-key
      (merge milestone-data { status: new-status })
    )
    (ok true)
  )
)

;; Verify milestone completion (admin only)
(define-public (verify-milestone (applicant principal) (milestone-id uint))
  (let (
    (milestone-key { applicant: applicant, milestone-id: milestone-id })
    (milestone-data (unwrap! (map-get? milestones milestone-key) (err u404)))
  )
    (asserts! (is-admin) (err u403))
    (asserts! (is-eq (get status milestone-data) STATUS-COMPLETED) (err u402))

    (map-set milestones
      milestone-key
      (merge milestone-data { status: STATUS-VERIFIED })
    )
    (ok true)
  )
)

;; Get milestone details
(define-read-only (get-milestone (applicant principal) (milestone-id uint))
  (map-get? milestones { applicant: applicant, milestone-id: milestone-id })
)

;; Get milestone count for an applicant
(define-read-only (get-milestone-count (applicant principal))
  (default-to u0 (map-get? milestone-count applicant))
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
