(define-map balances { user: principal } { balance: uint })

(define-constant ERR_INSUFFICIENT_FUNDS (err u100))
(define-constant ERR_AMOUNT_ZERO (err u101))

(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) ERR_AMOUNT_ZERO)
    (let ((current-balance (default-to { balance: u0 } (map-get? balances { user: tx-sender }))))
      (map-set balances { user: tx-sender } { balance: (+ amount (get balance current-balance)) })
    )
    (ok true)
  )
)

(define-public (withdraw (amount uint))
  (begin
    (asserts! (> amount u0) ERR_AMOUNT_ZERO)
    (let ((current-balance (default-to { balance: u0 } (map-get? balances { user: tx-sender }))))
      (if (>= (get balance current-balance) amount)
          (begin
            (map-set balances { user: tx-sender } { balance: (- (get balance current-balance) amount) })
            (ok true)
          )
          (ok false) ;; Adjusting to return the same type
      )
    )
  )
)


(define-read-only (get-balance (user principal))
  (default-to u0 (get balance (map-get? balances { user: user })))
)
