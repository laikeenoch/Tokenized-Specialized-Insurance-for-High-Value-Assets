;; Claim Verification Contract
;; Validates loss events and documentation

(define-data-var admin principal tx-sender)

;; Claim data structure
(define-map claims
  { claim-id: uint }
  {
    policy-id: uint,
    asset-id: uint,
    claimant: principal,
    amount: uint,
    description: (string-utf8 256),
    evidence-hash: (buff 32),
    status: (string-utf8 20),  ;; "pending", "approved", "rejected", "paid"
    submission-date: uint,
    decision-date: uint
  }
)

;; Claim reviews
(define-map claim-reviews
  { claim-id: uint }
  {
    reviewer: principal,
    notes: (string-utf8 256),
    recommendation: (string-utf8 20)  ;; "approve", "reject", "investigate"
  }
)

(define-data-var next-claim-id uint u1)

;; Submit a new claim
(define-public (submit-claim
                (policy-id uint)
                (asset-id uint)
                (amount uint)
                (description (string-utf8 256))
                (evidence-hash (buff 32)))
  (let
    (
      (claim-id (var-get next-claim-id))
    )
    ;; Verify policy exists and is active (would call policy-management contract in a real implementation)

    (map-set claims
      { claim-id: claim-id }
      {
        policy-id: policy-id,
        asset-id: asset-id,
        claimant: tx-sender,
        amount: amount,
        description: description,
        evidence-hash: evidence-hash,
        status: u"pending",
        submission-date: block-height,
        decision-date: u0
      }
    )

    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

;; Review a claim (admin only)
(define-public (review-claim (claim-id uint) (notes (string-utf8 256)) (recommendation (string-utf8 20)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))

    (map-set claim-reviews
      { claim-id: claim-id }
      {
        reviewer: tx-sender,
        notes: notes,
        recommendation: recommendation
      }
    )
    (ok true)
  )
)

;; Approve a claim (admin only)
(define-public (approve-claim (claim-id uint))
  (let
    (
      (claim (unwrap! (map-get? claims { claim-id: claim-id }) (err u1)))
    )
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-eq (get status claim) u"pending") (err u2))

    (map-set claims
      { claim-id: claim-id }
      (merge claim {
        status: u"approved",
        decision-date: block-height
      })
    )
    (ok true)
  )
)

;; Reject a claim (admin only)
(define-public (reject-claim (claim-id uint) (reason (string-utf8 256)))
  (let
    (
      (claim (unwrap! (map-get? claims { claim-id: claim-id }) (err u1)))
    )
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-eq (get status claim) u"pending") (err u2))

    (map-set claims
      { claim-id: claim-id }
      (merge claim {
        status: u"rejected",
        decision-date: block-height
      })
    )

    ;; Add rejection reason to review notes
    (map-set claim-reviews
      { claim-id: claim-id }
      {
        reviewer: tx-sender,
        notes: reason,
        recommendation: u"reject"
      }
    )

    (ok true)
  )
)

;; Get claim details
(define-read-only (get-claim (claim-id uint))
  (map-get? claims { claim-id: claim-id })
)

;; Get claim review details
(define-read-only (get-claim-review (claim-id uint))
  (map-get? claim-reviews { claim-id: claim-id })
)

;; Submit additional evidence for a claim
(define-public (submit-additional-evidence (claim-id uint) (evidence-hash (buff 32)))
  (let
    (
      (claim (unwrap! (map-get? claims { claim-id: claim-id }) (err u1)))
    )
    (asserts! (is-eq tx-sender (get claimant claim)) (err u403))
    (asserts! (is-eq (get status claim) u"pending") (err u2))

    (map-set claims
      { claim-id: claim-id }
      (merge claim { evidence-hash: evidence-hash })
    )
    (ok true)
  )
)
