;; Farm Verification Contract
;; Validates legitimate agricultural producers

(define-data-var admin principal tx-sender)

;; Farm data structure
(define-map farms
  { farm-id: uint }
  {
    owner: principal,
    name: (string-utf8 100),
    location: (string-utf8 100),
    verified: bool,
    registration-date: uint
  }
)

;; Farm ID counter
(define-data-var farm-id-counter uint u0)

;; Register a new farm
(define-public (register-farm (name (string-utf8 100)) (location (string-utf8 100)))
  (let ((new-id (+ (var-get farm-id-counter) u1)))
    (begin
      (var-set farm-id-counter new-id)
      (map-set farms
        { farm-id: new-id }
        {
          owner: tx-sender,
          name: name,
          location: location,
          verified: false,
          registration-date: block-height
        }
      )
      (ok new-id)
    )
  )
)

;; Verify a farm (admin only)
(define-public (verify-farm (farm-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (match (map-get? farms { farm-id: farm-id })
      farm-data (begin
        (map-set farms
          { farm-id: farm-id }
          (merge farm-data { verified: true })
        )
        (ok true)
      )
      (err u404)
    )
  )
)

;; Get farm details
(define-read-only (get-farm (farm-id uint))
  (map-get? farms { farm-id: farm-id })
)

;; Check if farm is verified
(define-read-only (is-farm-verified (farm-id uint))
  (match (map-get? farms { farm-id: farm-id })
    farm-data (ok (get verified farm-data))
    (err u404)
  )
)

;; Transfer farm ownership
(define-public (transfer-farm-ownership (farm-id uint) (new-owner principal))
  (match (map-get? farms { farm-id: farm-id })
    farm-data (begin
      (asserts! (is-eq tx-sender (get owner farm-data)) (err u403))
      (map-set farms
        { farm-id: farm-id }
        (merge farm-data { owner: new-owner })
      )
      (ok true)
    )
    (err u404)
  )
)
