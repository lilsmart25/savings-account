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

;; Add these at the top with other constants
(define-constant REFERRAL_BONUS u50) ;; 50 basis points (0.5%)
(define-map referrals { referrer: principal } { total-referrals: uint })

(define-public (refer-user (new-user principal))
    (begin
        (let ((referrer-stats (default-to { total-referrals: u0 } 
                             (map-get? referrals { referrer: tx-sender }))))
            (map-set referrals 
                { referrer: tx-sender }
                { total-referrals: (+ u1 (get total-referrals referrer-stats)) })
            (ok true))))


(define-map savings-streak 
    { user: principal } 
    { consecutive-deposits: uint, last-deposit: uint })

(define-public (track-deposit-streak)
    (let ((current-streak (default-to 
            { consecutive-deposits: u0, last-deposit: block-height }
            (map-get? savings-streak { user: tx-sender }))))
        (map-set savings-streak 
            { user: tx-sender }
            { consecutive-deposits: (+ u1 (get consecutive-deposits current-streak)),
              last-deposit: block-height })
        (ok true)))



(define-constant ROUND_UP_MULTIPLIER u10)

(define-public (round-up-deposit (amount uint))
    (let ((rounded-amount (* (/ (+ amount u9) u10) u10)))
        (deposit (- rounded-amount amount))))



(define-map savings-challenges 
    { user: principal }
    { challenge-type: (string-ascii 20),
      target: uint,
      start-date: uint,
      end-date: uint,
      completed: bool })

(define-public (start-challenge (challenge-type (string-ascii 20)) (target uint) (duration uint))
    (begin
        (map-set savings-challenges
            { user: tx-sender }
            { challenge-type: challenge-type,
              target: target,
              start-date: block-height,
              end-date: (+ block-height duration),
              completed: false })
        (ok true)))



(define-map savings-pools
    { pool-id: uint }
    { members: (list 10 principal),
      target: uint,
      current-amount: uint })

(define-data-var pool-counter uint u0)

(define-public (create-pool (target uint))
    (begin
        (var-set pool-counter (+ (var-get pool-counter) u1))
        (map-set savings-pools
            { pool-id: (var-get pool-counter) }
            { members: (list tx-sender),
              target: target,
              current-amount: u0 })
        (ok (var-get pool-counter))))



(define-map scheduled-deposits
    { user: principal }
    { amount: uint,
      interval: uint,
      last-deposit: uint,
      active: bool })

(define-public (setup-auto-deposit (amount uint) (interval uint))
    (begin
        (map-set scheduled-deposits
            { user: tx-sender }
            { amount: amount,
              interval: interval,
              last-deposit: block-height,
              active: true })
        (ok true)))



(define-map withdrawal-locks
    { user: principal }
    { locked-until: uint,
      emergency-contact: principal })

(define-public (set-withdrawal-lock (duration uint))
    (begin
        (map-set withdrawal-locks
            { user: tx-sender }
            { locked-until: (+ block-height duration),
              emergency-contact: tx-sender })
        (ok true)))
