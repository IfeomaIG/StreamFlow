;; StreamFlow - Continuous Payment Streaming System
;; A smart contract for automated continuous payments and real-time value streaming on Stacks

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u600))
(define-constant err-stream-not-found (err u601))
(define-constant err-balance-insufficient (err u602))
(define-constant err-invalid-parameters (err u603))
(define-constant err-stream-inactive (err u604))
(define-constant err-unauthorized-access (err u605))

;; Data Variables
(define-data-var service-fee-basis-points uint u300) ;; 3% service fee
(define-data-var minimum-stream-amount uint u1000) ;; Minimum 1000 micro-STX per stream

;; Data Maps
(define-map payment-streams
    { stream-id: uint }
    {
        sender: principal,
        receiver: principal,
        flow-rate: uint,
        total-deposit: uint,
        start-block: uint,
        end-block: uint,
        withdrawn-total: uint,
        stream-status: bool
    }
)

(define-map account-balances
    { account: principal }
    { balance: uint }
)

(define-map stream-counter
    { counter-key: bool }
    { total-streams: uint }
)

;; Initialize stream counter
(map-set stream-counter { counter-key: true } { total-streams: u0 })

;; Read-only functions

(define-read-only (get-stream-details (stream-id uint))
    (map-get? payment-streams { stream-id: stream-id })
)

(define-read-only (get-account-balance (account principal))
    (default-to u0 (get balance (map-get? account-balances { account: account })))
)

(define-read-only (get-service-fee-basis-points)
    (var-get service-fee-basis-points)
)

(define-read-only (get-minimum-stream-amount)
    (var-get minimum-stream-amount)
)

(define-read-only (calculate-available-withdrawal (stream-id uint))
    (match (map-get? payment-streams { stream-id: stream-id })
        stream-details
        (let
            (
                (current-block stacks-block-height)
                (start-block (get start-block stream-details))
                (end-block (get end-block stream-details))
                (flow-rate (get flow-rate stream-details))
                (withdrawn-total (get withdrawn-total stream-details))
                (stream-status (get stream-status stream-details))
            )
            (if (and stream-status (>= current-block start-block))
                (let
                    (
                        (elapsed-blocks (if (>= current-block end-block)
                                       (- end-block start-block)
                                       (- current-block start-block)))
                        (total-earned (* elapsed-blocks flow-rate))
                    )
                    (if (>= total-earned withdrawn-total)
                        (ok (- total-earned withdrawn-total))
                        (ok u0)
                    )
                )
                (ok u0)
            )
        )
        (err err-stream-not-found)
    )
)

;; Public functions

(define-public (deposit-funds (amount uint))
    (let
        (
            (current-balance (get-account-balance tx-sender))
        )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set account-balances 
            { account: tx-sender } 
            { balance: (+ current-balance amount) }
        )
        (ok true)
    )
)

(define-public (withdraw-funds (amount uint))
    (let
        (
            (current-balance (get-account-balance tx-sender))
        )
        (asserts! (>= current-balance amount) err-balance-insufficient)
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set account-balances 
            { account: tx-sender } 
            { balance: (- current-balance amount) }
        )
        (ok true)
    )
)

(define-public (create-stream (receiver principal) (flow-rate uint) (stream-duration uint))
    (let
        (
            (stream-id (+ (default-to u0 (get total-streams (map-get? stream-counter { counter-key: true }))) u1))
            (total-deposit (* flow-rate stream-duration))
            (sender-balance (get-account-balance tx-sender))
        )
        ;; Validate parameters
        (asserts! (>= total-deposit (var-get minimum-stream-amount)) err-invalid-parameters)
        (asserts! (> flow-rate u0) err-invalid-parameters)
        (asserts! (> stream-duration u0) err-invalid-parameters)
        (asserts! (>= sender-balance total-deposit) err-balance-insufficient)
        
        ;; Lock funds from sender balance
        (map-set account-balances 
            { account: tx-sender } 
            { balance: (- sender-balance total-deposit) }
        )
        
        ;; Create payment stream
        (map-set payment-streams
            { stream-id: stream-id }
            {
                sender: tx-sender,
                receiver: receiver,
                flow-rate: flow-rate,
                total-deposit: total-deposit,
                start-block: stacks-block-height,
                end-block: (+ stacks-block-height stream-duration),
                withdrawn-total: u0,
                stream-status: true
            }
        )
        
        ;; Increment stream counter
        (map-set stream-counter { counter-key: true } { total-streams: stream-id })
        
        (ok stream-id)
    )
)

(define-public (claim-payment (stream-id uint))
    (match (map-get? payment-streams { stream-id: stream-id })
        stream-details
        (let
            (
                (receiver (get receiver stream-details))
                (available-result (calculate-available-withdrawal stream-id))
            )
            (asserts! (is-eq tx-sender receiver) err-unauthorized-access)
            (asserts! (get stream-status stream-details) err-stream-inactive)
            
            (match available-result
                available-amount
                (if (> available-amount u0)
                    (let
                        (
                            (service-fee (/ (* available-amount (var-get service-fee-basis-points)) u10000))
                            (net-payment (- available-amount service-fee))
                            (current-withdrawn (get withdrawn-total stream-details))
                        )
                        ;; Transfer to receiver
                        (try! (as-contract (stx-transfer? net-payment tx-sender receiver)))
                        
                        ;; Transfer service fee to owner
                        (try! (as-contract (stx-transfer? service-fee tx-sender contract-owner)))
                        
                        ;; Update stream withdrawn amount
                        (map-set payment-streams
                            { stream-id: stream-id }
                            (merge stream-details { withdrawn-total: (+ current-withdrawn available-amount) })
                        )
                        
                        (ok net-payment)
                    )
                    (ok u0)
                )
                error-code
                error-code
            )
        )
        err-stream-not-found
    )
)

(define-public (cancel-stream (stream-id uint))
    (match (map-get? payment-streams { stream-id: stream-id })
        stream-details
        (let
            (
                (sender (get sender stream-details))
                (receiver (get receiver stream-details))
                (total-deposit (get total-deposit stream-details))
                (withdrawn-total (get withdrawn-total stream-details))
            )
            (asserts! (or (is-eq tx-sender sender) (is-eq tx-sender receiver)) err-unauthorized-access)
            (asserts! (get stream-status stream-details) err-stream-inactive)
            
            ;; First, process any pending payment for receiver
            (match (calculate-available-withdrawal stream-id)
                available-amount
                (if (> available-amount u0)
                    (let
                        (
                            (service-fee (/ (* available-amount (var-get service-fee-basis-points)) u10000))
                            (net-payment (- available-amount service-fee))
                        )
                        (try! (as-contract (stx-transfer? net-payment tx-sender receiver)))
                        (try! (as-contract (stx-transfer? service-fee tx-sender contract-owner)))
                        (map-set payment-streams
                            { stream-id: stream-id }
                            (merge stream-details { withdrawn-total: (+ withdrawn-total available-amount) })
                        )
                        true
                    )
                    true
                )
                error-code
                false
            )
            
            ;; Return unstreamed funds to sender
            (let
                (
                    (final-withdrawn (get withdrawn-total (unwrap-panic (map-get? payment-streams { stream-id: stream-id }))))
                    (remaining-funds (- total-deposit final-withdrawn))
                    (sender-balance (get-account-balance sender))
                )
                (if (> remaining-funds u0)
                    (map-set account-balances 
                        { account: sender } 
                        { balance: (+ sender-balance remaining-funds) }
                    )
                    true
                )
            )
            
            ;; Deactivate stream
            (map-set payment-streams
                { stream-id: stream-id }
                (merge stream-details { stream-status: false })
            )
            
            (ok true)
        )
        err-stream-not-found
    )
)

;; Owner functions

(define-public (update-service-fee (new-fee-basis-points uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee-basis-points u2000) err-invalid-parameters) ;; Max 20% fee
        (var-set service-fee-basis-points new-fee-basis-points)
        (ok true)
    )
)

(define-public (update-minimum-stream-amount (new-minimum uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set minimum-stream-amount new-minimum)
        (ok true)
    )
)