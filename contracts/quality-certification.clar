;; Quality Certification Contract
;; Records inspection results

(define-data-var admin principal tx-sender)

;; Certifier data structure
(define-map certifiers
  { certifier-id: principal }
  {
    name: (string-utf8 100),
    active: bool
  }
)

;; Certification data structure
(define-map certifications
  { certification-id: uint }
  {
    crop-id: uint,
    certifier: principal,
    grade: (string-utf8 10),
    notes: (string-utf8 200),
    certification-date: uint,
    expiry-date: uint,
    revoked: bool
  }
)

;; Certification ID counter
(define-data-var certification-id-counter uint u0)

;; Register a certifier (admin only)
(define-public (register-certifier
    (certifier principal)
    (name (string-utf8 100))
  )
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (map-set certifiers
      { certifier-id: certifier }
      {
        name: name,
        active: true
      }
    )
    (ok true)
  )
)

;; Deactivate a certifier (admin only)
(define-public (deactivate-certifier (certifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (match (map-get? certifiers { certifier-id: certifier })
      certifier-data (begin
        (map-set certifiers
          { certifier-id: certifier }
          (merge certifier-data { active: false })
        )
        (ok true)
      )
      (err u404)
    )
  )
)

;; Issue a certification
(define-public (issue-certification
    (crop-id uint)
    (grade (string-utf8 10))
    (notes (string-utf8 200))
    (validity-period uint)
  )
  (match (map-get? certifiers { certifier-id: tx-sender })
    certifier-data (begin
      (asserts! (get active certifier-data) (err u403))
      (let ((new-id (+ (var-get certification-id-counter) u1)))
        (begin
          (var-set certification-id-counter new-id)
          (map-set certifications
            { certification-id: new-id }
            {
              crop-id: crop-id,
              certifier: tx-sender,
              grade: grade,
              notes: notes,
              certification-date: block-height,
              expiry-date: (+ block-height validity-period),
              revoked: false
            }
          )
          (ok new-id)
        )
      )
    )
    (err u401)
  )
)

;; Revoke a certification
(define-public (revoke-certification (certification-id uint))
  (match (map-get? certifications { certification-id: certification-id })
    cert-data (begin
      (asserts! (or
        (is-eq tx-sender (get certifier cert-data))
        (is-eq tx-sender (var-get admin))
      ) (err u403))
      (map-set certifications
        { certification-id: certification-id }
        (merge cert-data { revoked: true })
      )
      (ok true)
    )
    (err u404)
  )
)

;; Get certification details
(define-read-only (get-certification (certification-id uint))
  (map-get? certifications { certification-id: certification-id })
)

;; Check if certification is valid
(define-read-only (is-certification-valid (certification-id uint))
  (match (map-get? certifications { certification-id: certification-id })
    cert-data (ok (and
      (not (get revoked cert-data))
      (<= block-height (get expiry-date cert-data))
    ))
    (err u404)
  )
)
