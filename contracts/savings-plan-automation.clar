;; Savings Plan Automation Contract
;; Provides structured savings plans with automatic milestone tracking and goal adjustments

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_PLAN (err u301))
(define-constant ERR_PLAN_NOT_FOUND (err u302))
(define-constant ERR_PLAN_INACTIVE (err u303))
(define-constant ERR_INSUFFICIENT_BALANCE (err u304))
(define-constant ERR_INVALID_AMOUNT (err u305))
(define-constant ERR_MILESTONE_NOT_REACHED (err u306))
(define-constant ERR_PLAN_COMPLETED (err u307))
(define-constant ERR_INVALID_FREQUENCY (err u308))

;; Plan types
(define-constant EMERGENCY_FUND u1)
(define-constant VACATION_FUND u2)
(define-constant HOME_DOWN_PAYMENT u3)
(define-constant RETIREMENT_FUND u4)
(define-constant EDUCATION_FUND u5)
(define-constant CUSTOM_GOAL u6)

;; Frequency types
(define-constant WEEKLY u7)
(define-constant MONTHLY u30)
(define-constant QUARTERLY u90)

;; Data variables
(define-data-var plan-counter uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var system-enabled bool true)

;; Savings plan structure
(define-map savings-plans
    { user: principal, plan-id: uint }
    {
        plan-type: uint,
        target-amount: uint,
        current-amount: uint,
        target-date: uint,
        auto-contribution: uint,
        contribution-frequency: uint,
        last-contribution: uint,
        active: bool,
        created-at: uint,
        milestones-achieved: uint,
        reward-balance: uint
    }
)

;; Plan milestones and rewards
(define-map plan-milestones
    { plan-id: uint, milestone-percent: uint }
    {
        target-amount: uint,
        reward-amount: uint,
        achieved: bool,
        achieved-at: uint
    }
)

;; User plan summaries
(define-map user-plan-summaries
    { user: principal }
    {
        active-plans: uint,
        completed-plans: uint,
        total-saved: uint,
        total-rewards: uint,
        success-rate: uint
    }
)

;; Create a new savings plan
(define-public (create-savings-plan 
    (plan-type uint)
    (target-amount uint))
    (let ((new-plan-id (+ (var-get plan-counter) u1)))
        (begin
            (asserts! (var-get system-enabled) ERR_UNAUTHORIZED)
            (asserts! (> target-amount u0) ERR_INVALID_AMOUNT)
            
            ;; Create the savings plan
            (map-set savings-plans
                { user: tx-sender, plan-id: new-plan-id }
                {
                    plan-type: plan-type,
                    target-amount: target-amount,
                    current-amount: u0,
                    target-date: (+ block-height u2016), ;; Default 1 week
                    auto-contribution: u0,
                    contribution-frequency: WEEKLY,
                    last-contribution: block-height,
                    active: true,
                    created-at: block-height,
                    milestones-achieved: u0,
                    reward-balance: u0
                })
            
            ;; Initialize milestones
            (map-set plan-milestones
                { plan-id: new-plan-id, milestone-percent: u25 }
                {
                    target-amount: (/ (* target-amount u25) u100),
                    reward-amount: (/ target-amount u200), ;; 0.5% reward
                    achieved: false,
                    achieved-at: u0
                })
            
            (map-set plan-milestones
                { plan-id: new-plan-id, milestone-percent: u50 }
                {
                    target-amount: (/ (* target-amount u50) u100),
                    reward-amount: (/ target-amount u100), ;; 1% reward
                    achieved: false,
                    achieved-at: u0
                })
            
            (map-set plan-milestones
                { plan-id: new-plan-id, milestone-percent: u75 }
                {
                    target-amount: (/ (* target-amount u75) u100),
                    reward-amount: (/ (* target-amount u15) u1000), ;; 1.5% reward
                    achieved: false,
                    achieved-at: u0
                })
            
            (map-set plan-milestones
                { plan-id: new-plan-id, milestone-percent: u100 }
                {
                    target-amount: target-amount,
                    reward-amount: (/ target-amount u50), ;; 2% completion bonus
                    achieved: false,
                    achieved-at: u0
                })
            
            ;; Update counters
            (var-set plan-counter new-plan-id)
            
            (ok new-plan-id))))

;; Contribute to a savings plan
(define-public (contribute-to-plan (plan-id uint) (amount uint))
    (let ((plan (unwrap! (map-get? savings-plans { user: tx-sender, plan-id: plan-id }) ERR_PLAN_NOT_FOUND)))
        (begin
            (asserts! (get active plan) ERR_PLAN_INACTIVE)
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            (asserts! (< (get current-amount plan) (get target-amount plan)) ERR_PLAN_COMPLETED)
            
            ;; Calculate new amount (cap at target)
            (let ((new-amount (+ (get current-amount plan) amount))
                  (capped-amount (if (> new-amount (get target-amount plan))
                                    (get target-amount plan)
                                    new-amount))
                  (actual-contribution (- capped-amount (get current-amount plan))))
                
                ;; Update plan with new amount
                (map-set savings-plans
                    { user: tx-sender, plan-id: plan-id }
                    (merge plan 
                        {
                            current-amount: capped-amount,
                            last-contribution: block-height
                        }))
                
                ;; Check for milestone rewards (simplified)
                (let ((progress-percent (/ (* capped-amount u100) (get target-amount plan))))
                    (if (and (>= progress-percent u25) (< (get milestones-achieved plan) u1))
                        (map-set savings-plans
                            { user: tx-sender, plan-id: plan-id }
                            (merge (unwrap-panic (map-get? savings-plans { user: tx-sender, plan-id: plan-id }))
                                {
                                    reward-balance: (+ (get reward-balance plan) (/ (get target-amount plan) u200)),
                                    milestones-achieved: u1
                                }))
                        true))
                
                (ok actual-contribution)))))

;; Execute automatic contribution
(define-public (execute-auto-contribution (plan-id uint))
    (let ((plan (unwrap! (map-get? savings-plans { user: tx-sender, plan-id: plan-id }) ERR_PLAN_NOT_FOUND))
          (blocks-since-last (- block-height (get last-contribution plan))))
        (begin
            (asserts! (get active plan) ERR_PLAN_INACTIVE)
            (asserts! (> (get auto-contribution plan) u0) ERR_INVALID_AMOUNT)
            (asserts! (>= blocks-since-last (get contribution-frequency plan)) ERR_INVALID_PLAN)
            
            ;; Execute the contribution
            (try! (contribute-to-plan plan-id (get auto-contribution plan)))
            
            (ok (get auto-contribution plan)))))

;; Claim milestone rewards
(define-public (claim-milestone-rewards (plan-id uint))
    (let ((plan (unwrap! (map-get? savings-plans { user: tx-sender, plan-id: plan-id }) ERR_PLAN_NOT_FOUND)))
        (begin
            (asserts! (> (get reward-balance plan) u0) ERR_INSUFFICIENT_BALANCE)
            
            ;; Reset reward balance and return rewards to user
            (map-set savings-plans
                { user: tx-sender, plan-id: plan-id }
                (merge plan { reward-balance: u0 }))
            
            (ok (get reward-balance plan)))))

;; Pause/resume plan
(define-public (toggle-plan-status (plan-id uint))
    (let ((plan (unwrap! (map-get? savings-plans { user: tx-sender, plan-id: plan-id }) ERR_PLAN_NOT_FOUND)))
        (begin
            (map-set savings-plans
                { user: tx-sender, plan-id: plan-id }
                (merge plan { active: (not (get active plan)) }))
            (ok (not (get active plan))))))

;; Read-only functions
(define-read-only (get-plan-details (user principal) (plan-id uint))
    (map-get? savings-plans { user: user, plan-id: plan-id }))

(define-read-only (get-plan-milestones (plan-id uint))
    (ok {
        milestone-25: (map-get? plan-milestones { plan-id: plan-id, milestone-percent: u25 }),
        milestone-50: (map-get? plan-milestones { plan-id: plan-id, milestone-percent: u50 }),
        milestone-75: (map-get? plan-milestones { plan-id: plan-id, milestone-percent: u75 }),
        milestone-100: (map-get? plan-milestones { plan-id: plan-id, milestone-percent: u100 })
    }))

(define-read-only (get-user-summary (user principal))
    (map-get? user-plan-summaries { user: user }))

(define-read-only (get-system-stats)
    (ok {
        total-plans: (var-get plan-counter),
        total-rewards: (var-get total-rewards-distributed),
        system-enabled: (var-get system-enabled)
    }))

(define-read-only (calculate-plan-progress (user principal) (plan-id uint))
    (let ((plan (unwrap! (map-get? savings-plans { user: user, plan-id: plan-id }) ERR_PLAN_NOT_FOUND)))
        (ok {
            progress-percentage: (/ (* (get current-amount plan) u100) (get target-amount plan)),
            amount-remaining: (- (get target-amount plan) (get current-amount plan)),
            days-remaining: (- (get target-date plan) block-height),
            on-track: (>= (/ (* (get current-amount plan) u100) (get target-amount plan)) u50)
        })))
