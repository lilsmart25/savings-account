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



;; Add these constants
(define-constant INTEREST_RATE u5) ;; 5% annual interest
(define-constant BLOCKS_PER_YEAR u52560) ;; approximate blocks in a year

(define-map last-interest-block { user: principal } { block: uint })

(define-public (accrue-interest)
    (let (
        (current-balance (default-to { balance: u0 } (map-get? balances { user: tx-sender })))
        (last-block (default-to { block: block-height } (map-get? last-interest-block { user: tx-sender })))
        (blocks-passed (- block-height (get block last-block)))
        (interest-amount (/ (* (get balance current-balance) INTEREST_RATE blocks-passed) (* u100 BLOCKS_PER_YEAR)))
    )
    (map-set balances { user: tx-sender } { balance: (+ (get balance current-balance) interest-amount) })
    (map-set last-interest-block { user: tx-sender } { block: block-height })
    (ok interest-amount))
)


(define-map savings-goals { user: principal } { target: uint, deadline: uint })

(define-public (set-savings-goal (target uint) (blocks uint))
    (begin
        (asserts! (> target u0) ERR_AMOUNT_ZERO)
        (map-set savings-goals { user: tx-sender } { target: target, deadline: (+ block-height blocks) })
        (ok true))
)

(define-read-only (check-goal-progress)
    (let (
        (goal (default-to { target: u0, deadline: u0 } (map-get? savings-goals { user: tx-sender })))
        (current-balance (get-balance tx-sender))
    )
    (ok {
        target: (get target goal),
        current: current-balance,
        remaining: (- (get target goal) current-balance),
        deadline: (get deadline goal)
    }))
)


(define-map emergency-contacts { user: principal } { contact: principal })

(define-public (set-emergency-contact (contact principal))
    (begin
        (map-set emergency-contacts { user: tx-sender } { contact: contact })
        (ok true))
)



(define-map transaction-history 
    { user: principal, tx-id: uint } 
    { amount: uint, type: (string-ascii 10), timestamp: uint })

(define-data-var tx-counter uint u0)

(define-private (log-transaction (amount uint) (type (string-ascii 10)))
    (begin
        (var-set tx-counter (+ (var-get tx-counter) u1))
        (map-set transaction-history 
            { user: tx-sender, tx-id: (var-get tx-counter) }
            { amount: amount, type: type, timestamp: block-height })
        (ok true))
)


(define-map daily-limits { user: principal } { limit: uint, last-withdrawal: uint, today-total: uint })

(define-public (set-daily-limit (limit uint))
    (begin
        (asserts! (> limit u0) ERR_AMOUNT_ZERO)
        (map-set daily-limits { user: tx-sender } { limit: limit, last-withdrawal: block-height, today-total: u0 })
        (ok true))
)


(define-map savings-buckets 
    { user: principal, category: (string-ascii 20) } 
    { amount: uint })

(define-public (create-bucket (category (string-ascii 20)) (initial-amount uint))
    (begin
        (asserts! (>= (get-balance tx-sender) initial-amount) ERR_INSUFFICIENT_FUNDS)
        (map-set savings-buckets 
            { user: tx-sender, category: category }
            { amount: initial-amount })
        (ok true))
)


(define-map auto-save-rules { user: principal } { percentage: uint, enabled: bool })

(define-public (set-auto-save (percentage uint))
    (begin
        (asserts! (<= percentage u100) (err u102))
        (map-set auto-save-rules 
            { user: tx-sender }
            { percentage: percentage, enabled: true })
        (ok true))
)

