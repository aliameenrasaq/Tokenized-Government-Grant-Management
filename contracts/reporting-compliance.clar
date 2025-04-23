;; Reporting Compliance Contract
;; Ensures proper documentation of outcomes

(define-data-var admin principal tx-sender)

;; Report status enum: 0=Submitted, 1=Approved, 2=Rejected
(define-constant STATUS-SUBMITTED u0)
(define-constant STATUS-APPROVED u1)
(define-constant STATUS-REJECTED u2)

;; Map to store reports by applicant and report ID
(define-map reports
  { applicant: principal, report-id: uint }
  {
    title: (string-ascii 100),
    milestone-id: uint,
    report-hash: (buff 32),
    submission-time: uint,
    status: uint,
    feedback: (string-ascii 500)
  }
)

;; Map to track report count per applicant
(define-map report-count principal uint)

;; Map to track verified applicants (simplified approach)
(define-map verified-applicants principal bool)

;; Map to track milestones (simplified approach)
(define-map milestones
  { applicant: principal, milestone-id: uint }
  bool
)

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

;; Register a milestone (admin only)
(define-public (register-milestone (applicant principal) (milestone-id uint))
  (begin
    (asserts! (is-admin) (err u403))
    (map-set milestones { applicant: applicant, milestone-id: milestone-id } true)
    (ok true)
  )
)

;; Submit a report for a milestone
(define-public (submit-report
  (title (string-ascii 100))
  (milestone-id uint)
  (report-hash (buff 32))
)
  (let (
    (current-count (default-to u0 (map-get? report-count tx-sender)))
    (new-count (+ current-count u1))
    (block-time (get-block-info? time u0))
  )
    (asserts! (is-verified tx-sender) (err u401))
    (asserts! (default-to false (map-get? milestones { applicant: tx-sender, milestone-id: milestone-id })) (err u404))

    (map-set reports
      { applicant: tx-sender, report-id: new-count }
      {
        title: title,
        milestone-id: milestone-id,
        report-hash: report-hash,
        submission-time: (default-to u0 block-time),
        status: STATUS-SUBMITTED,
        feedback: ""
      }
    )
    (map-set report-count tx-sender new-count)
    (ok new-count)
  )
)

;; Review a report (admin only)
(define-public (review-report
  (applicant principal)
  (report-id uint)
  (approved bool)
  (feedback (string-ascii 500))
)
  (let (
    (report-key { applicant: applicant, report-id: report-id })
    (report-data (unwrap! (map-get? reports report-key) (err u404)))
    (new-status (if approved STATUS-APPROVED STATUS-REJECTED))
  )
    (asserts! (is-admin) (err u403))
    (asserts! (is-eq (get status report-data) STATUS-SUBMITTED) (err u402))

    (map-set reports
      report-key
      (merge report-data {
        status: new-status,
        feedback: feedback
      })
    )
    (ok true)
  )
)

;; Get report details
(define-read-only (get-report (applicant principal) (report-id uint))
  (map-get? reports { applicant: applicant, report-id: report-id })
)

;; Get report count for an applicant
(define-read-only (get-report-count (applicant principal))
  (default-to u0 (map-get? report-count applicant))
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
