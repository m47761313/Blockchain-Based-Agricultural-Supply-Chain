;; Retail Distribution Contract
;; Manages final delivery to consumers

(define-constant contract-owner tx-sender)

;; Retailer data structure
(define-map retailers
  { retailer-id: principal }
  {
    name: (string-utf8 100),
    location: (string-utf8 100),
    verified: bool
  }
)

;; Product data structure
(define-map products
  { product-id: uint }
  {
    crop-id: uint,
    certification-id: (optional uint),
    retailer: principal,
    price: uint,
    listing-date: uint,
    sold: bool,
    sale-date: (optional uint),
    consumer: (optional principal)
  }
)

;; Product ID counter
(define-data-var product-id-counter uint u0)

;; Register a retailer
(define-public (register-retailer
    (name (string-utf8 100))
    (location (string-utf8 100))
  )
  (begin
    (map-set retailers
      { retailer-id: tx-sender }
      {
        name: name,
        location: location,
        verified: false
      }
    )
    (ok true)
  )
)

;; Verify a retailer (contract owner only)
(define-public (verify-retailer (retailer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u403))
    (match (map-get? retailers { retailer-id: retailer })
      retailer-data (begin
        (map-set retailers
          { retailer-id: retailer }
          (merge retailer-data { verified: true })
        )
        (ok true)
      )
      (err u404)
    )
  )
)

;; List a product for sale
(define-public (list-product
    (crop-id uint)
    (certification-id (optional uint))
    (price uint)
  )
  (match (map-get? retailers { retailer-id: tx-sender })
    retailer-data (begin
      (asserts! (get verified retailer-data) (err u403))
      (let ((new-id (+ (var-get product-id-counter) u1)))
        (begin
          (var-set product-id-counter new-id)
          (map-set products
            { product-id: new-id }
            {
              crop-id: crop-id,
              certification-id: certification-id,
              retailer: tx-sender,
              price: price,
              listing-date: block-height,
              sold: false,
              sale-date: none,
              consumer: none
            }
          )
          (ok new-id)
        )
      )
    )
    (err u401)
  )
)

;; Purchase a product
(define-public (purchase-product (product-id uint))
  (match (map-get? products { product-id: product-id })
    product-data (begin
      (asserts! (not (get sold product-data)) (err u400))
      (map-set products
        { product-id: product-id }
        (merge product-data {
          sold: true,
          sale-date: (some block-height),
          consumer: (some tx-sender)
        })
      )
      (ok true)
    )
    (err u404)
  )
)

;; Get product details
(define-read-only (get-product (product-id uint))
  (map-get? products { product-id: product-id })
)

;; Get products by retailer
(define-read-only (get-retailer-products (retailer principal))
  (map-get? retailers { retailer-id: retailer })
)

;; Check if product is certified
(define-read-only (is-product-certified (product-id uint))
  (match (map-get? products { product-id: product-id })
    product-data (ok (is-some (get certification-id product-data)))
    (err u404)
  )
)
