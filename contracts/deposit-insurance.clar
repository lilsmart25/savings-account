;; Smart Contract Deposit Insurance System
;; Provides protection for user deposits against contract failures and protocol risks

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_AMOUNT (err u201))
(define-constant ERR_POLICY_NOT_FOUND (err u202))
(define-constant ERR_POLICY_EXPIRED (err u203))
(define-constant ERR_INSUFFICIENT_COVERAGE (err u204))
(define-constant ERR_CLAIM_ALREADY_FILED (err u205))
(define-constant ERR_CLAIM_NOT_APPROVED (err u206))
(define-constant ERR_INVALID_COVERAGE_TYPE (err u207))
(define-constant ERR_PREMIUM_NOT_PAID (err u208))
(define-constant ERR_INSUFFICIENT_POOL (err u209))
(define-constant ERR_RISK_TOO_HIGH (err u210))

;; Insurance coverage types
(define-constant BASIC_COVERAGE u1)
(define-constant STANDARD_COVERAGE u2)
(define-constant PREMIUM_COVERAGE u3)
(define-constant ENTERPRISE_COVERAGE u4)

;; Claim status types
(define-constant CLAIM_PENDING u1)
(define-constant CLAIM_APPROVED u2)
(define-constant CLAIM_REJECTED u3)
(define-constant CLAIM_PAID u4)

;; Risk assessment levels
(define-constant LOW_RISK u1)
(define-constant MEDIUM_RISK u2)
(define-constant HIGH_RISK u3)
(define-constant CRITICAL_RISK u4)

;; Insurance pool and contract state variables
(define-data-var insurance-pool uint u0)
(define-data-var total-claims-paid uint u0)
(define-data-var policy-counter uint u0)
(define-data-var claim-counter uint u0)
(define-data-var contract-admin principal tx-sender)

;; Coverage configuration map
(define-map coverage-configs
    { coverage-type: uint }
    { max-coverage: uint, premium-rate: uint, deductible: uint, term-blocks: uint })

;; User insurance policies
(define-map insurance-policies
    { user: principal, policy-id: uint }
    { coverage-type: uint,
      coverage-amount: uint,
      premium-paid: uint,
      start-block: uint,
      end-block: uint,
      active: bool,
      protected-balance: uint })

;; Insurance claims tracking
(define-map insurance-claims
    { claim-id: uint }
    { claimant: principal,
      policy-id: uint,
      claim-amount: uint,
      incident-type: (string-ascii 30),
      status: uint,
      filed-at: uint,
      processed-at: uint,
      evidence-hash: (string-ascii 64) })

;; Risk assessment for users
(define-map user-risk-profiles
    { user: principal }
    { risk-score: uint,
      last-assessment: uint,
      incident-history: uint,
      premium-multiplier: uint })

;; Contract performance metrics
(define-map performance-metrics
    { period: uint }
    { total-policies: uint,
      active-policies: uint,
      claims-filed: uint,
      claims-approved: uint,
      pool-utilization: uint })

;; Initialize insurance coverage configurations
(define-public (initialize-coverage-configs)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
        ;; Basic coverage: 50% max coverage, 2% premium rate, 5% deductible, 1 year term
        (map-set coverage-configs
            { coverage-type: BASIC_COVERAGE }
            { max-coverage: u50000, premium-rate: u200, deductible: u500, term-blocks: u52560 })
        ;; Standard coverage: 75% max coverage, 3% premium rate, 3% deductible, 1 year term
        (map-set coverage-configs
            { coverage-type: STANDARD_COVERAGE }
            { max-coverage: u100000, premium-rate: u300, deductible: u300, term-blocks: u52560 })
        ;; Premium coverage: 90% max coverage, 4% premium rate, 1% deductible, 1 year term
        (map-set coverage-configs
            { coverage-type: PREMIUM_COVERAGE }
            { max-coverage: u250000, premium-rate: u400, deductible: u100, term-blocks: u52560 })
        ;; Enterprise coverage: 95% max coverage, 5% premium rate, 0.5% deductible, 1 year term
        (map-set coverage-configs
            { coverage-type: ENTERPRISE_COVERAGE }
            { max-coverage: u500000, premium-rate: u500, deductible: u50, term-blocks: u52560 })
        (ok true)))

;; Purchase insurance policy
(define-public (purchase-policy (coverage-type uint) (coverage-amount uint))
    (let ((config (unwrap! (map-get? coverage-configs { coverage-type: coverage-type }) ERR_INVALID_COVERAGE_TYPE))
          (user-risk (default-to 
              { risk-score: LOW_RISK, last-assessment: block-height, incident-history: u0, premium-multiplier: u100 }
              (map-get? user-risk-profiles { user: tx-sender })))
          (base-premium (/ (* coverage-amount (get premium-rate config)) u10000))
          (adjusted-premium (/ (* base-premium (get premium-multiplier user-risk)) u100)))
        (begin
            (asserts! (> coverage-amount u0) ERR_INVALID_AMOUNT)
            (asserts! (<= coverage-amount (get max-coverage config)) ERR_INSUFFICIENT_COVERAGE)
            (asserts! (<= (get risk-score user-risk) HIGH_RISK) ERR_RISK_TOO_HIGH)
            ;; Increment policy counter
            (var-set policy-counter (+ (var-get policy-counter) u1))
            ;; Create new policy
            (map-set insurance-policies
                { user: tx-sender, policy-id: (var-get policy-counter) }
                { coverage-type: coverage-type,
                  coverage-amount: coverage-amount,
                  premium-paid: adjusted-premium,
                  start-block: block-height,
                  end-block: (+ block-height (get term-blocks config)),
                  active: true,
                  protected-balance: u0 })
            ;; Add premium to insurance pool
            (var-set insurance-pool (+ (var-get insurance-pool) adjusted-premium))
            (ok (var-get policy-counter)))))

;; Update protected balance when user deposits
(define-public (update-protected-balance (policy-id uint) (new-balance uint))
    (let ((policy (unwrap! (map-get? insurance-policies { user: tx-sender, policy-id: policy-id }) ERR_POLICY_NOT_FOUND)))
        (begin
            (asserts! (get active policy) ERR_POLICY_EXPIRED)
            (asserts! (<= block-height (get end-block policy)) ERR_POLICY_EXPIRED)
            (asserts! (<= new-balance (get coverage-amount policy)) ERR_INSUFFICIENT_COVERAGE)
            (map-set insurance-policies
                { user: tx-sender, policy-id: policy-id }
                { coverage-type: (get coverage-type policy),
                  coverage-amount: (get coverage-amount policy),
                  premium-paid: (get premium-paid policy),
                  start-block: (get start-block policy),
                  end-block: (get end-block policy),
                  active: (get active policy),
                  protected-balance: new-balance })
            (ok true))))

;; File insurance claim
(define-public (file-claim (policy-id uint) (claim-amount uint) (incident-type (string-ascii 30)) (evidence-hash (string-ascii 64)))
    (let ((policy (unwrap! (map-get? insurance-policies { user: tx-sender, policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
          (config (unwrap! (map-get? coverage-configs { coverage-type: (get coverage-type policy) }) ERR_INVALID_COVERAGE_TYPE)))
        (begin
            (asserts! (get active policy) ERR_POLICY_EXPIRED)
            (asserts! (<= block-height (get end-block policy)) ERR_POLICY_EXPIRED)
            (asserts! (> claim-amount u0) ERR_INVALID_AMOUNT)
            (asserts! (<= claim-amount (get protected-balance policy)) ERR_INSUFFICIENT_COVERAGE)
            ;; Increment claim counter
            (var-set claim-counter (+ (var-get claim-counter) u1))
            ;; Create new claim
            (map-set insurance-claims
                { claim-id: (var-get claim-counter) }
                { claimant: tx-sender,
                  policy-id: policy-id,
                  claim-amount: claim-amount,
                  incident-type: incident-type,
                  status: CLAIM_PENDING,
                  filed-at: block-height,
                  processed-at: u0,
                  evidence-hash: evidence-hash })
            (ok (var-get claim-counter)))))

;; Assess user risk profile
(define-public (assess-user-risk (user principal))
    (let ((current-risk (default-to 
              { risk-score: LOW_RISK, last-assessment: u0, incident-history: u0, premium-multiplier: u100 }
              (map-get? user-risk-profiles { user: user })))
          (blocks-since-last (- block-height (get last-assessment current-risk)))
          (new-risk-score (if (> (get incident-history current-risk) u3)
                             HIGH_RISK
                             (if (> (get incident-history current-risk) u1)
                                 MEDIUM_RISK
                                 LOW_RISK)))
          (new-multiplier (if (is-eq new-risk-score HIGH_RISK)
                             u150
                             (if (is-eq new-risk-score MEDIUM_RISK)
                                 u125
                                 u100))))
        (begin
            (map-set user-risk-profiles
                { user: user }
                { risk-score: new-risk-score,
                  last-assessment: block-height,
                  incident-history: (get incident-history current-risk),
                  premium-multiplier: new-multiplier })
            (ok new-risk-score))))

;; Process claim (admin function)
(define-public (process-claim (claim-id uint) (approve bool))
    (let ((claim (unwrap! (map-get? insurance-claims { claim-id: claim-id }) ERR_CLAIM_NOT_APPROVED)))
        (begin
            (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status claim) CLAIM_PENDING) ERR_CLAIM_ALREADY_FILED)
            (if approve
                (let ((claim-amount (get claim-amount claim))
                      (claimant (get claimant claim)))
                    (begin
                        (asserts! (>= (var-get insurance-pool) claim-amount) ERR_INSUFFICIENT_POOL)
                        ;; Update claim status to approved
                        (map-set insurance-claims
                            { claim-id: claim-id }
                            { claimant: (get claimant claim),
                              policy-id: (get policy-id claim),
                              claim-amount: (get claim-amount claim),
                              incident-type: (get incident-type claim),
                              status: CLAIM_APPROVED,
                              filed-at: (get filed-at claim),
                              processed-at: block-height,
                              evidence-hash: (get evidence-hash claim) })
                        ;; Deduct from insurance pool
                        (var-set insurance-pool (- (var-get insurance-pool) claim-amount))
                        (var-set total-claims-paid (+ (var-get total-claims-paid) claim-amount))
                        ;; Update claimant's incident history
                        (let ((user-risk (default-to 
                                  { risk-score: LOW_RISK, last-assessment: block-height, incident-history: u0, premium-multiplier: u100 }
                                  (map-get? user-risk-profiles { user: claimant }))))
                            (map-set user-risk-profiles
                                { user: claimant }
                                { risk-score: (get risk-score user-risk),
                                  last-assessment: (get last-assessment user-risk),
                                  incident-history: (+ (get incident-history user-risk) u1),
                                  premium-multiplier: (get premium-multiplier user-risk) }))
                        (ok true)))
                (begin
                    ;; Reject claim
                    (map-set insurance-claims
                        { claim-id: claim-id }
                        { claimant: (get claimant claim),
                          policy-id: (get policy-id claim),
                          claim-amount: (get claim-amount claim),
                          incident-type: (get incident-type claim),
                          status: CLAIM_REJECTED,
                          filed-at: (get filed-at claim),
                          processed-at: block-height,
                          evidence-hash: (get evidence-hash claim) })
                    (ok false))))))

;; Add funds to insurance pool (for protocol revenue sharing)
(define-public (fund-insurance-pool (amount uint))
    (begin
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (var-set insurance-pool (+ (var-get insurance-pool) amount))
        (ok true)))

;; Calculate policy premium quote
(define-read-only (get-premium-quote (coverage-type uint) (coverage-amount uint) (user principal))
    (let ((config (unwrap! (map-get? coverage-configs { coverage-type: coverage-type }) ERR_INVALID_COVERAGE_TYPE))
          (user-risk (default-to 
              { risk-score: LOW_RISK, last-assessment: u0, incident-history: u0, premium-multiplier: u100 }
              (map-get? user-risk-profiles { user: user })))
          (base-premium (/ (* coverage-amount (get premium-rate config)) u10000))
          (adjusted-premium (/ (* base-premium (get premium-multiplier user-risk)) u100)))
        (ok {
            base-premium: base-premium,
            risk-multiplier: (get premium-multiplier user-risk),
            final-premium: adjusted-premium,
            deductible: (/ (* coverage-amount (get deductible config)) u10000),
            max-coverage: (get max-coverage config)
        })))

;; Get user's active policies
(define-read-only (get-user-policies (user principal))
    (ok {
        policy-count: (var-get policy-counter),
        risk-profile: (default-to 
            { risk-score: LOW_RISK, last-assessment: u0, incident-history: u0, premium-multiplier: u100 }
            (map-get? user-risk-profiles { user: user }))
    }))

;; Get policy details
(define-read-only (get-policy-details (user principal) (policy-id uint))
    (map-get? insurance-policies { user: user, policy-id: policy-id }))

;; Get claim details
(define-read-only (get-claim-details (claim-id uint))
    (map-get? insurance-claims { claim-id: claim-id }))

;; Get insurance pool status
(define-read-only (get-pool-status)
    (ok {
        total-pool: (var-get insurance-pool),
        total-claims-paid: (var-get total-claims-paid),
        total-policies: (var-get policy-counter),
        total-claims: (var-get claim-counter),
        pool-utilization: (if (> (var-get insurance-pool) u0)
                             (/ (* (var-get total-claims-paid) u100) (var-get insurance-pool))
                             u0)
    }))

;; Check if user has valid coverage for amount
(define-read-only (check-coverage (user principal) (amount uint))
    (let ((policy-1 (map-get? insurance-policies { user: user, policy-id: u1 }))
          (policy-2 (map-get? insurance-policies { user: user, policy-id: u2 }))
          (policy-3 (map-get? insurance-policies { user: user, policy-id: u3 })))
        (ok (or 
            (and (is-some policy-1) 
                 (get active (unwrap-panic policy-1))
                 (>= (get coverage-amount (unwrap-panic policy-1)) amount)
                 (<= block-height (get end-block (unwrap-panic policy-1))))
            (and (is-some policy-2) 
                 (get active (unwrap-panic policy-2))
                 (>= (get coverage-amount (unwrap-panic policy-2)) amount)
                 (<= block-height (get end-block (unwrap-panic policy-2))))
            (and (is-some policy-3) 
                 (get active (unwrap-panic policy-3))
                 (>= (get coverage-amount (unwrap-panic policy-3)) amount)
                 (<= block-height (get end-block (unwrap-panic policy-3))))))))

;; Renew existing policy
(define-public (renew-policy (policy-id uint))
    (let ((policy (unwrap! (map-get? insurance-policies { user: tx-sender, policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
          (config (unwrap! (map-get? coverage-configs { coverage-type: (get coverage-type policy) }) ERR_INVALID_COVERAGE_TYPE))
          (user-risk (default-to 
              { risk-score: LOW_RISK, last-assessment: block-height, incident-history: u0, premium-multiplier: u100 }
              (map-get? user-risk-profiles { user: tx-sender })))
          (base-premium (/ (* (get coverage-amount policy) (get premium-rate config)) u10000))
          (adjusted-premium (/ (* base-premium (get premium-multiplier user-risk)) u100)))
        (begin
            (asserts! (<= (get risk-score user-risk) HIGH_RISK) ERR_RISK_TOO_HIGH)
            ;; Update policy with new terms
            (map-set insurance-policies
                { user: tx-sender, policy-id: policy-id }
                { coverage-type: (get coverage-type policy),
                  coverage-amount: (get coverage-amount policy),
                  premium-paid: adjusted-premium,
                  start-block: block-height,
                  end-block: (+ block-height (get term-blocks config)),
                  active: true,
                  protected-balance: (get protected-balance policy) })
            ;; Add premium to insurance pool
            (var-set insurance-pool (+ (var-get insurance-pool) adjusted-premium))
            (ok adjusted-premium))))




