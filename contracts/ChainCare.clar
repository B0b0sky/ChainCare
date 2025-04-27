;; ChainCare - Healthcare records management system
;; Allows patients to control access to their medical data and monetize anonymous health statistics

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_REGISTERED (err u102))
(define-constant ERR_INVALID_PROVIDER (err u103))
(define-constant ERR_ALREADY_AUTHORIZED (err u104))
(define-constant ERR_NOT_AUTHORIZED (err u105))
(define-constant ERR_INVALID_PARAMETER (err u106))
(define-constant ERR_SELF_AUTHORIZATION (err u107))
(define-constant ERR_ZERO_AMOUNT (err u108))
(define-constant ERR_EMPTY_STRING (err u109))

;; Data maps
(define-map patients 
  { patient-id: principal }
  { registered: bool, data-hash: (optional (buff 32)), anonymous-sharing: bool }
)

(define-map provider-access
  { patient-id: principal, provider-id: principal }
  { authorized: bool, last-access: uint }
)

(define-map providers
  { provider-id: principal }
  { registered: bool, name: (string-utf8 50) }
)

(define-map research-contributions
  { patient-id: principal, research-id: uint }
  { contributed: bool, reward: uint }
)

(define-map research-projects
  { research-id: uint }
  { active: bool, reward-per-contribution: uint, data-type: (string-utf8 50) }
)

(define-data-var next-research-id uint u1)
(define-data-var access-counter uint u0)

;; Patient functions
(define-public (register-patient)
  (let ((caller tx-sender))
    (asserts! (is-none (get registered (map-get? patients {patient-id: caller}))) ERR_ALREADY_REGISTERED)
    (ok (map-set patients 
      {patient-id: caller} 
      {registered: true, data-hash: none, anonymous-sharing: false}))
  )
)

(define-public (update-medical-record (data-hash (buff 32)))
  (let ((caller tx-sender))
    (asserts! (is-some (map-get? patients {patient-id: caller})) ERR_NOT_REGISTERED)
    (ok (map-set patients 
      {patient-id: caller} 
      (merge (unwrap! (map-get? patients {patient-id: caller}) ERR_NOT_REGISTERED)
             {data-hash: (some data-hash)})))
  )
)

(define-public (authorize-provider (provider-id principal))
  (let ((caller tx-sender))
    ;; Check that provider-id is not the caller (can't authorize yourself)
    (asserts! (not (is-eq provider-id caller)) ERR_SELF_AUTHORIZATION)
    (asserts! (is-some (map-get? patients {patient-id: caller})) ERR_NOT_REGISTERED)
    (asserts! (is-some (map-get? providers {provider-id: provider-id})) ERR_INVALID_PROVIDER)
    (asserts! (is-none (map-get? provider-access {patient-id: caller, provider-id: provider-id})) ERR_ALREADY_AUTHORIZED)
    (ok (map-set provider-access 
      {patient-id: caller, provider-id: provider-id} 
      {authorized: true, last-access: u0}))
  )
)

(define-public (revoke-provider-access (provider-id principal))
  (let ((caller tx-sender))
    ;; Check that provider-id is not the caller
    (asserts! (not (is-eq provider-id caller)) ERR_SELF_AUTHORIZATION)
    (asserts! (is-some (map-get? patients {patient-id: caller})) ERR_NOT_REGISTERED)
    (asserts! (is-some (map-get? provider-access {patient-id: caller, provider-id: provider-id})) ERR_NOT_AUTHORIZED)
    (var-set access-counter (+ (var-get access-counter) u1))
    (ok (map-set provider-access 
      {patient-id: caller, provider-id: provider-id} 
      {authorized: false, last-access: (var-get access-counter)}))
  )
)

(define-public (toggle-anonymous-sharing)
  (let ((caller tx-sender)
        (current-patient (unwrap! (map-get? patients {patient-id: caller}) ERR_NOT_REGISTERED))
        (current-sharing (get anonymous-sharing current-patient)))
    (ok (map-set patients 
      {patient-id: caller} 
      (merge current-patient {anonymous-sharing: (not current-sharing)})))
  )
)

;; Provider functions
(define-public (register-provider (name (string-utf8 50)))
  (let ((caller tx-sender))
    ;; Check that name is not empty
    (asserts! (> (len name) u0) ERR_EMPTY_STRING)
    (asserts! (is-none (map-get? providers {provider-id: caller})) ERR_ALREADY_REGISTERED)
    (ok (map-set providers 
      {provider-id: caller} 
      {registered: true, name: name}))
  )
)

(define-public (access-patient-record (patient-id principal))
  (let ((caller tx-sender))
    ;; Check that patient-id is not the caller (provider can't access their own record as a provider)
    (asserts! (not (is-eq patient-id caller)) ERR_SELF_AUTHORIZATION)
    (asserts! (is-some (map-get? patients {patient-id: patient-id})) ERR_NOT_REGISTERED)
    (let ((access-info (unwrap! (map-get? provider-access {patient-id: patient-id, provider-id: caller}) ERR_NOT_AUTHORIZED)))
      (asserts! (get authorized access-info) ERR_UNAUTHORIZED)
      (var-set access-counter (+ (var-get access-counter) u1))
      (map-set provider-access 
        {patient-id: patient-id, provider-id: caller} 
        (merge access-info {last-access: (var-get access-counter)}))
      (ok (get data-hash (unwrap! (map-get? patients {patient-id: patient-id}) ERR_NOT_REGISTERED))))
  )
)

;; Research functions
(define-public (create-research-project (reward-per-contribution uint) (data-type (string-utf8 50)))
  (let ((research-id (var-get next-research-id)))
    ;; Check that reward is not zero and data-type is not empty
    (asserts! (> reward-per-contribution u0) ERR_ZERO_AMOUNT)
    (asserts! (> (len data-type) u0) ERR_EMPTY_STRING)
    (map-set research-projects 
      {research-id: research-id} 
      {active: true, reward-per-contribution: reward-per-contribution, data-type: data-type})
    (var-set next-research-id (+ research-id u1))
    (ok research-id)
  )
)

(define-public (contribute-to-research (research-id uint))
  (let ((caller tx-sender))
    ;; Check that research-id exists
    (asserts! (is-some (map-get? research-projects {research-id: research-id})) ERR_INVALID_PARAMETER)
    (let ((patient-data (unwrap! (map-get? patients {patient-id: caller}) ERR_NOT_REGISTERED))
          (research (unwrap! (map-get? research-projects {research-id: research-id}) ERR_NOT_REGISTERED)))
      (asserts! (get anonymous-sharing patient-data) ERR_UNAUTHORIZED)
      (asserts! (get active research) ERR_UNAUTHORIZED)
      (asserts! (is-none (map-get? research-contributions {patient-id: caller, research-id: research-id})) ERR_ALREADY_REGISTERED)
      (map-set research-contributions 
        {patient-id: caller, research-id: research-id} 
        {contributed: true, reward: (get reward-per-contribution research)})
      (ok true))
  )
)

(define-public (claim-research-reward (research-id uint))
  (let ((caller tx-sender))
    ;; Check that research-id exists
    (asserts! (is-some (map-get? research-projects {research-id: research-id})) ERR_INVALID_PARAMETER)
    (let ((contribution (unwrap! (map-get? research-contributions {patient-id: caller, research-id: research-id}) ERR_NOT_AUTHORIZED)))
      (asserts! (get contributed contribution) ERR_UNAUTHORIZED)
      ;; In a real contract, this would transfer STX or a custom token to the patient
      ;; For simplicity, we're just marking the reward as claimed by setting contributed to false
      (map-set research-contributions 
        {patient-id: caller, research-id: research-id} 
        {contributed: false, reward: (get reward contribution)})
      (ok (get reward contribution)))
  )
)

;; Read-only functions
(define-read-only (get-patient-info (patient-id principal))
  (map-get? patients {patient-id: patient-id})
)

(define-read-only (check-provider-access (patient-id principal) (provider-id principal))
  (map-get? provider-access {patient-id: patient-id, provider-id: provider-id})
)

(define-read-only (get-provider-info (provider-id principal))
  (map-get? providers {provider-id: provider-id})
)

(define-read-only (get-research-project (research-id uint))
  (map-get? research-projects {research-id: research-id})
)

(define-read-only (get-contribution-info (patient-id principal) (research-id uint))
  (map-get? research-contributions {patient-id: patient-id, research-id: research-id})
)
