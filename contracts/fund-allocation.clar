;; Fund Allocation Contract
;; Manages distribution of approved funding

(define-data-var admin principal tx-sender)
(define-data-var total-funds uint u0)
(define-data-var funds-allocated uint u0)

;; Map to track allocated funds per applicant
(define-map allocated-funds principal uint)

;; Map to track claimed funds per applicant
(define-map claimed-funds principal uint)

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

;; Add funds to the grant pool (admin only)
(define-public (add-funds (amount uint))
  (begin
    (asserts! (is-admin) (err u403))
    (var-set total-funds (+ (var-get total-funds) amount))
    (ok true)
  )
)

;; Allocate funds to an applicant (admin only)
(define-public (allocate-funds (applicant principal) (amount uint))
  (begin
    (asserts! (is-admin) (err u403))
    (asserts! (is-verified applicant) (err u401))
    (asserts! (<= (+ (var-get funds-allocated) amount) (var-get total-funds)) (err u501))

    (map-set allocated-funds applicant
      (+ (default-to u0 (map-get? allocated-funds applicant)) amount)
    )
    (var-set funds-allocated (+ (var-get funds-allocated) amount))
    (ok true)
  )
)

;; Claim allocated funds (applicant only)
(define-public (claim-funds (amount uint))
  (let (
    (allocated (default-to u0 (map-get? allocated-funds tx-sender)))
    (claimed (default-to u0 (map-get? claimed-funds tx-sender)))
  )
    (asserts! (is-verified tx-sender) (err u401))
    (asserts! (<= (+ claimed amount) allocated) (err u502))

    (map-set claimed-funds tx-sender (+ claimed amount))
    (ok true)
  )
)

;; Get available funds for an applicant
(define-read-only (get-available-funds (applicant principal))
  (let (
    (allocated (default-to u0 (map-get? allocated-funds applicant)))
    (claimed (default-to u0 (map-get? claimed-funds applicant)))
  )
    (- allocated claimed)
  )
)

;; Get total remaining funds in the pool
(define-read-only (get-remaining-funds)
  (- (var-get total-funds) (var-get funds-allocated))
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
