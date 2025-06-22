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


;; Add at the top with other constants
(define-constant BASIC_TYPE u1)
(define-constant PREMIUM_TYPE u2)
(define-constant VIP_TYPE u3)

(define-map account-types { user: principal } { type: uint })

(define-public (upgrade-account-type (new-type uint))
    (begin
        (asserts! (or (is-eq new-type BASIC_TYPE) 
                     (is-eq new-type PREMIUM_TYPE)
                     (is-eq new-type VIP_TYPE)) 
                 (err u103))
        (map-set account-types { user: tx-sender } { type: new-type })
        (ok true)))


(define-constant MILESTONE_1 u1000)
(define-constant MILESTONE_2 u5000)
(define-constant MILESTONE_3 u10000)

(define-map achieved-milestones { user: principal } { milestones: (list 10 uint) })

(define-public (check-milestones)
    (let ((balance (get-balance tx-sender)))
        (begin
            (if (>= balance MILESTONE_1)
                (map-set achieved-milestones 
                    { user: tx-sender }
                    { milestones: (list MILESTONE_1) })
                true)
            (ok true))))


(define-map beneficiaries { account: principal } { beneficiary: principal })

(define-public (set-beneficiary (beneficiary-address principal))
    (begin
        (map-set beneficiaries 
            { account: tx-sender }
            { beneficiary: beneficiary-address })
        (ok true)))


(define-map recovery-keys 
    { user: principal } 
    { backup-key: (string-ascii 50), created-at: uint })

(define-public (set-recovery-key (backup-key (string-ascii 50)))
    (begin
        (map-set recovery-keys 
            { user: tx-sender }
            { backup-key: backup-key, created-at: block-height })
        (ok true)))


(define-map category-savings 
    { user: principal, category: (string-ascii 20) } 
    { current: uint, target: uint })

(define-public (create-category-goal (category (string-ascii 20)) (target uint))
    (begin
        (asserts! (> target u0) ERR_AMOUNT_ZERO)
        (map-set category-savings 
            { user: tx-sender, category: category }
            { current: u0, target: target })
        (ok true)))


(define-map notification-settings 
    { user: principal } 
    { notify-above: uint, enabled: bool })

(define-public (set-notification-threshold (amount uint))
    (begin
        (asserts! (> amount u0) ERR_AMOUNT_ZERO)
        (map-set notification-settings 
            { user: tx-sender }
            { notify-above: amount, enabled: true })
        (ok true)))


(define-map activity-stats 
    { user: principal } 
    { deposits-count: uint, withdrawals-count: uint, last-active: uint })

(define-public (update-activity-stats (action (string-ascii 10)))
    (let ((current-stats (default-to 
            { deposits-count: u0, withdrawals-count: u0, last-active: block-height }
            (map-get? activity-stats { user: tx-sender }))))
        (map-set activity-stats 
            { user: tx-sender }
            { deposits-count: (if (is-eq action "deposit")
                (+ u1 (get deposits-count current-stats))
                (get deposits-count current-stats)),
              withdrawals-count: (if (is-eq action "withdraw")
                (+ u1 (get withdrawals-count current-stats))
                (get withdrawals-count current-stats)),
              last-active: block-height })
        (ok true)))


(define-map achievements 
    { user: principal } 
    { badges: (list 10 (string-ascii 20)), points: uint })

(define-public (award-achievement (badge (string-ascii 20)))
    (let ((current-achievements (default-to 
            { badges: (list ), points: u0 }
            (map-get? achievements { user: tx-sender }))))
        (map-set achievements 
            { user: tx-sender }
            { badges: (unwrap-panic (as-max-len? 
                (append (get badges current-achievements) badge) u10)),
              points: (+ u10 (get points current-achievements)) })
        (ok true)))



(define-constant TIER1_THRESHOLD u1000)
(define-constant TIER2_THRESHOLD u5000)
(define-constant TIER3_THRESHOLD u10000)
(define-constant TIER1_RATE u5)
(define-constant TIER2_RATE u7)
(define-constant TIER3_RATE u10)

(define-public (get-applicable-interest-rate)
  (let ((balance (get-balance tx-sender)))
    (ok (if (>= balance TIER3_THRESHOLD) 
          TIER3_RATE
          (if (>= balance TIER2_THRESHOLD)
            TIER2_RATE
            (if (>= balance TIER1_THRESHOLD)
              TIER1_RATE
              INTEREST_RATE))))))
(define-public (accrue-tiered-interest)
  (let (
    (current-balance (default-to { balance: u0 } (map-get? balances { user: tx-sender })))
    (last-block (default-to { block: block-height } (map-get? last-interest-block { user: tx-sender })))
    (blocks-passed (- block-height (get block last-block)))
    (applicable-rate (unwrap-panic (get-applicable-interest-rate)))
    (interest-amount (/ (* (get balance current-balance) applicable-rate blocks-passed) (* u100 BLOCKS_PER_YEAR)))
  )
    (map-set balances { user: tx-sender } { balance: (+ (get balance current-balance) interest-amount) })
    (map-set last-interest-block { user: tx-sender } { block: block-height })
    (ok interest-amount)))




(define-map joint-accounts 
  { account-id: uint } 
  { owners: (list 5 principal), balance: uint })

(define-data-var joint-account-counter uint u0)

(define-public (create-joint-account (co-owner principal))
  (begin
    (var-set joint-account-counter (+ (var-get joint-account-counter) u1))
    (map-set joint-accounts
      { account-id: (var-get joint-account-counter) }
      { owners: (list tx-sender co-owner), balance: u0 })
    (ok (var-get joint-account-counter))))

(define-public (deposit-to-joint-account (account-id uint) (amount uint))
  (let ((account (default-to { owners: (list ), balance: u0 } (map-get? joint-accounts { account-id: account-id }))))
    (begin
      (asserts! (> amount u0) ERR_AMOUNT_ZERO)
      (asserts! (is-some (index-of (get owners account) tx-sender)) (err u104))
      (map-set joint-accounts 
        { account-id: account-id }
        { owners: (get owners account), balance: (+ amount (get balance account)) })
      (ok true))))

(define-public (withdraw-from-joint-account (account-id uint) (amount uint))
  (let ((account (default-to { owners: (list ), balance: u0 } (map-get? joint-accounts { account-id: account-id }))))
    (begin
      (asserts! (> amount u0) ERR_AMOUNT_ZERO)
      (asserts! (is-some (index-of (get owners account) tx-sender)) (err u104))
      (asserts! (>= (get balance account) amount) ERR_INSUFFICIENT_FUNDS)
      (map-set joint-accounts 
        { account-id: account-id }
        { owners: (get owners account), balance: (- (get balance account) amount) })
      (ok true))))



(define-constant LADDER_BONUS_RATE u2)

(define-map timed-deposits
  { user: principal, deposit-id: uint }
  { amount: uint, lock-until: uint, bonus-rate: uint })

(define-data-var deposit-id-counter uint u0)

(define-public (create-timed-deposit (amount uint) (lock-blocks uint))
  (let ((user-balance (get-balance tx-sender)))
    (begin
      (asserts! (> amount u0) ERR_AMOUNT_ZERO)
      (asserts! (>= user-balance amount) ERR_INSUFFICIENT_FUNDS)
      (var-set deposit-id-counter (+ (var-get deposit-id-counter) u1))
      (map-set balances 
        { user: tx-sender } 
        { balance: (- user-balance amount) })
      (map-set timed-deposits
        { user: tx-sender, deposit-id: (var-get deposit-id-counter) }
        { amount: amount, 
          lock-until: (+ block-height lock-blocks), 
          bonus-rate: LADDER_BONUS_RATE })
      (ok (var-get deposit-id-counter)))))



(define-map spending-categories
  { user: principal, category: (string-ascii 20) }
  { total-spent: uint, last-updated: uint })

(define-public (record-spending (amount uint) (category (string-ascii 20)))
  (let ((current-data (default-to 
                      { total-spent: u0, last-updated: block-height }
                      (map-get? spending-categories { user: tx-sender, category: category }))))
    (begin
      (asserts! (> amount u0) ERR_AMOUNT_ZERO)
      (map-set spending-categories
        { user: tx-sender, category: category }
        { total-spent: (+ amount (get total-spent current-data)),
          last-updated: block-height })
      (ok true))))

(define-read-only (get-category-spending (category (string-ascii 20)))
  (let ((data (default-to 
              { total-spent: u0, last-updated: u0 }
              (map-get? spending-categories { user: tx-sender, category: category }))))
    (ok (get total-spent data))))

(define-read-only (get-spending-summary)
  (ok {
    food: (unwrap-panic (get-category-spending "food")),
    housing: (unwrap-panic (get-category-spending "housing")),
    transport: (unwrap-panic (get-category-spending "transport")),
    entertainment: (unwrap-panic (get-category-spending "entertainment"))
  }))



  (define-map boost-events
  { event-id: uint }
  { multiplier: uint, start-block: uint, end-block: uint, active: bool })

(define-data-var event-counter uint u0)

(define-public (create-boost-event (multiplier uint) (duration uint))
  (begin
    (var-set event-counter (+ (var-get event-counter) u1))
    (map-set boost-events
      { event-id: (var-get event-counter) }
      { multiplier: multiplier,
        start-block: block-height,
        end-block: (+ block-height duration),
        active: true })
    (ok (var-get event-counter))))

(define-public (deposit-with-boost (amount uint) (event-id uint))
  (let ((event (default-to 
               { multiplier: u0, start-block: u0, end-block: u0, active: false }
               (map-get? boost-events { event-id: event-id })))
        (boosted-amount (/ (* amount (get multiplier event)) u100)))
    (begin
      (asserts! (> amount u0) ERR_AMOUNT_ZERO)
      (asserts! (get active event) (err u106))
      (asserts! (and (>= block-height (get start-block event))
                    (<= block-height (get end-block event))) (err u107))
      (let ((current-balance (default-to { balance: u0 } (map-get? balances { user: tx-sender }))))
        (map-set balances 
          { user: tx-sender } 
          { balance: (+ (+ amount boosted-amount) (get balance current-balance)) }))
      (ok (+ amount boosted-amount)))))




(define-map round-up-rules
  { user: principal }
  { enabled: bool, round-to: uint })

(define-public (set-round-up-rule (enabled bool) (round-to uint))
  (begin
    (asserts! (> round-to u0) ERR_AMOUNT_ZERO)
    (map-set round-up-rules
      { user: tx-sender }
      { enabled: enabled, round-to: round-to })
    (ok true)))


(define-map token-balances 
    { user: principal, token-contract: principal } 
    { balance: uint })

(define-public (deposit-token (token-contract principal) (amount uint))
    (let ((sender tx-sender))
        (begin
            (asserts! (> amount u0) ERR_AMOUNT_ZERO)
            ;; (try! (contract-call? token-contract transfer amount sender (as-contract tx-sender) none))
            (let ((current-balance (default-to { balance: u0 } 
                (map-get? token-balances { user: sender, token-contract: token-contract }))))
                (map-set token-balances 
                    { user: sender, token-contract: token-contract }
                    { balance: (+ amount (get balance current-balance)) })
                (ok true)))))

(define-public (withdraw-token (token-contract principal) (amount uint))
    (let ((sender tx-sender)
          (current-balance (default-to { balance: u0 } 
            (map-get? token-balances { user: sender, token-contract: token-contract }))))
        (begin
            (asserts! (>= (get balance current-balance) amount) ERR_INSUFFICIENT_FUNDS)
            ;; (try! (as-contract (contract-call? token-contract transfer 
                ;; amount 
                ;; (as-contract tx-sender)
                ;; sender 
                ;; none)))
            (map-set token-balances 
                { user: sender, token-contract: token-contract }
                { balance: (- (get balance current-balance) amount) })
            (ok true))))

(define-read-only (get-token-balance (user principal) (token-contract principal))
    (default-to u0 
        (get balance (map-get? token-balances { user: user, token-contract: token-contract }))))



(define-constant REWARD_PERCENTAGE u5)
(define-constant MIN_GOAL_AMOUNT u1000)

(define-map savings-rewards
    { user: principal }
    { goal-amount: uint, current-streak: uint, rewards-earned: uint })

(define-public (set-reward-goal (goal-amount uint))
    (begin
        (asserts! (>= goal-amount MIN_GOAL_AMOUNT) ERR_AMOUNT_ZERO)
        (map-set savings-rewards
            { user: tx-sender }
            { goal-amount: goal-amount, current-streak: u0, rewards-earned: u0 })
        (ok true)))

(define-public (check-and-claim-rewards)
    (let ((user-rewards (default-to 
            { goal-amount: u0, current-streak: u0, rewards-earned: u0 }
            (map-get? savings-rewards { user: tx-sender })))
          (current-balance (get-balance tx-sender)))
        (if (>= current-balance (get goal-amount user-rewards))
            (let ((reward-amount (/ (* current-balance REWARD_PERCENTAGE) u100)))
                (begin
                    (map-set balances 
                        { user: tx-sender }
                        { balance: (+ current-balance reward-amount) })
                    (map-set savings-rewards
                        { user: tx-sender }
                        { goal-amount: (get goal-amount user-rewards),
                          current-streak: (+ (get current-streak user-rewards) u1),
                          rewards-earned: (+ (get rewards-earned user-rewards) reward-amount) })
                    (ok reward-amount)))
            (ok u0))))

(define-constant COMPOUND_DAILY u1)
(define-constant COMPOUND_WEEKLY u7)
(define-constant COMPOUND_MONTHLY u30)
(define-constant COMPOUND_QUARTERLY u90)
(define-constant COMPOUND_ANNUALLY u365)

(define-map compound-settings
    { user: principal }
    { frequency: uint, last-compound: uint, auto-compound: bool })

(define-map interest-projections
    { user: principal }
    { projected-balance: uint, projection-date: uint, annual-rate: uint })

(define-data-var compound-counter uint u0)

(define-public (set-compound-frequency (frequency uint))
    (begin
        (asserts! (or (is-eq frequency COMPOUND_DAILY)
                     (is-eq frequency COMPOUND_WEEKLY)
                     (is-eq frequency COMPOUND_MONTHLY)
                     (is-eq frequency COMPOUND_QUARTERLY)
                     (is-eq frequency COMPOUND_ANNUALLY))
                 (err u108))
        (map-set compound-settings
            { user: tx-sender }
            { frequency: frequency, last-compound: block-height, auto-compound: true })
        (ok true)))


(define-public (execute-compound-interest)
    (let ((settings (default-to 
            { frequency: COMPOUND_ANNUALLY, last-compound: block-height, auto-compound: false }
            (map-get? compound-settings { user: tx-sender })))
          (current-balance (default-to { balance: u0 } (map-get? balances { user: tx-sender })))
          (blocks-since-last (- block-height (get last-compound settings))))
        (if (and (get auto-compound settings) 
                (>= blocks-since-last (get frequency settings)))
            (let ((applicable-rate (unwrap-panic (get-applicable-interest-rate)))
                  (periods-passed (/ blocks-since-last (get frequency settings)))
                  (rate-per-period (/ applicable-rate (get frequency settings)))
                  (compound-amount (/ (* (get balance current-balance) rate-per-period periods-passed) u100)))
                (begin
                    (map-set balances 
                        { user: tx-sender } 
                        { balance: (+ (get balance current-balance) compound-amount) })
                    (map-set compound-settings
                        { user: tx-sender }
                        { frequency: (get frequency settings),
                          last-compound: block-height,
                          auto-compound: (get auto-compound settings) })
                    (var-set compound-counter (+ (var-get compound-counter) u1))
                    (ok compound-amount)))
            (ok u0))))



(define-read-only (get-compound-schedule)
    (let ((settings (default-to 
            { frequency: COMPOUND_ANNUALLY, last-compound: block-height, auto-compound: false }
            (map-get? compound-settings { user: tx-sender }))))
        (ok {
            frequency: (get frequency settings),
            last-compound: (get last-compound settings),
            next-compound: (+ (get last-compound settings) (get frequency settings)),
            auto-compound-enabled: (get auto-compound settings),
            blocks-until-next: (- (+ (get last-compound settings) (get frequency settings)) block-height)
        })))

(define-public (toggle-auto-compound)
    (let ((current-settings (default-to 
            { frequency: COMPOUND_ANNUALLY, last-compound: block-height, auto-compound: false }
            (map-get? compound-settings { user: tx-sender }))))
        (begin
            (map-set compound-settings
                { user: tx-sender }
                { frequency: (get frequency current-settings),
                  last-compound: (get last-compound current-settings),
                  auto-compound: (not (get auto-compound current-settings)) })
            (ok (not (get auto-compound current-settings))))))


