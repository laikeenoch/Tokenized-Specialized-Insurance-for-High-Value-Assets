;; Asset Verification Contract
;; Validates legitimate high-value items

(define-data-var admin principal tx-sender)

;; Asset data structure
(define-map assets
  { asset-id: uint }
  {
    owner: principal,
    value: uint,
    description: (string-utf8 256),
    verified: bool,
    verification-date: uint
  }
)

;; Asset verification requests
(define-map verification-requests
  { request-id: uint }
  {
    asset-id: uint,
    owner: principal,
    value: uint,
    description: (string-utf8 256),
    status: (string-utf8 20) ;; "pending", "approved", "rejected"
  }
)

(define-data-var next-asset-id uint u1)
(define-data-var next-request-id uint u1)

;; Request asset verification
(define-public (request-verification (value uint) (description (string-utf8 256)))
  (let
    (
      (request-id (var-get next-request-id))
      (asset-id (var-get next-asset-id))
    )
    (map-set verification-requests
      { request-id: request-id }
      {
        asset-id: asset-id,
        owner: tx-sender,
        value: value,
        description: description,
        status: u"pending"
      }
    )
    (var-set next-request-id (+ request-id u1))
    (var-set next-asset-id (+ asset-id u1))
    (ok request-id)
  )
)

;; Approve asset verification (admin only)
(define-public (approve-verification (request-id uint))
  (let
    (
      (request (unwrap! (map-get? verification-requests { request-id: request-id }) (err u1)))
    )
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-eq (get status request) u"pending") (err u2))

    ;; Update request status
    (map-set verification-requests
      { request-id: request-id }
      (merge request { status: u"approved" })
    )

    ;; Create verified asset
    (map-set assets
      { asset-id: (get asset-id request) }
      {
        owner: (get owner request),
        value: (get value request),
        description: (get description request),
        verified: true,
        verification-date: block-height
      }
    )
    (ok true)
  )
)

;; Reject asset verification (admin only)
(define-public (reject-verification (request-id uint))
  (let
    (
      (request (unwrap! (map-get? verification-requests { request-id: request-id }) (err u1)))
    )
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-eq (get status request) u"pending") (err u2))

    ;; Update request status
    (map-set verification-requests
      { request-id: request-id }
      (merge request { status: u"rejected" })
    )
    (ok true)
  )
)

;; Get asset details
(define-read-only (get-asset (asset-id uint))
  (map-get? assets { asset-id: asset-id })
)

;; Get verification request details
(define-read-only (get-verification-request (request-id uint))
  (map-get? verification-requests { request-id: request-id })
)

;; Transfer asset ownership
(define-public (transfer-asset (asset-id uint) (new-owner principal))
  (let
    (
      (asset (unwrap! (map-get? assets { asset-id: asset-id }) (err u1)))
    )
    (asserts! (is-eq tx-sender (get owner asset)) (err u403))

    (map-set assets
      { asset-id: asset-id }
      (merge asset { owner: new-owner })
    )
    (ok true)
  )
)

;; Update asset value (requires re-verification)
(define-public (update-asset-value (asset-id uint) (new-value uint))
  (let
    (
      (asset (unwrap! (map-get? assets { asset-id: asset-id }) (err u1)))
    )
    (asserts! (is-eq tx-sender (get owner asset)) (err u403))

    ;; Create a new verification request
    (let
      (
        (request-id (var-get next-request-id))
      )
      (map-set verification-requests
        { request-id: request-id }
        {
          asset-id: asset-id,
          owner: tx-sender,
          value: new-value,
          description: (get description asset),
          status: u"pending"
        }
      )
      (var-set next-request-id (+ request-id u1))
      (ok request-id)
    )
  )
)
