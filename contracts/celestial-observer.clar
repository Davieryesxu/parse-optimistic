;; =========================================================
;; PARSE-OPTIMISTIC: CELESTIAL OBSERVER REGISTRY
;; =========================================================
;; A decentralized, blockchain-native platform for recording
;; and validating astronomical observations using optimistic
;; parsing and community verification mechanisms.
;; =========================================================
;; =========================================================
;; Error Constants
;; =========================================================
(define-constant ERR-REGISTRATION-FAILED u100)
(define-constant ERR-OBSERVATION-INVALID u101)
(define-constant ERR-UNAUTHORIZED-ACTION u102)
(define-constant ERR-DUPLICATE-VERIFICATION u103)
(define-constant ERR-BADGE-CONFLICT u104)
(define-constant ERR-ACHIEVEMENT-REQUIREMENTS-UNMET u105)
(define-constant ERR-INVALID-INPUT u106)

;; =========================================================
;; Data Maps and Variables
;; =========================================================
(define-map observer-profiles
  { address: principal }
  {
    username: (string-utf8 50),
    registration-timestamp: uint,
    total-observations: uint,
    total-verifications: uint,
  }
)

(define-map cosmic-records
  { record-id: uint }
  {
    observer: principal,
    celestial-target: (string-utf8 100),
    object-classification: (string-utf8 50),
    sky-coordinates: {
      right-ascension: (string-utf8 20),
      declination: (string-utf8 20),
    },
    record-timestamp: uint,
    observation-context: {
      location: (string-utf8 100),
      atmospheric-conditions: (string-utf8 50),
      meteorological-data: (string-utf8 100),
    },
    equipment-details: (string-utf8 200),
    observer-notes: (string-utf8 500),
    evidence-signature: (optional (buff 32)),
    verification-tally: uint,
  }
)

(define-map verification-log
  {
    record-id: uint,
    verifier: principal,
  }
  { is-verified: bool }
)

(define-map achievement-badges
  { badge-id: uint }
  {
    badge-name: (string-utf8 50),
    badge-description: (string-utf8 200),
    badge-criteria: (string-utf8 200),
    badge-rarity: (string-utf8 20),
  }
)

(define-map astronomer-badge-collection
  {
    astronomer: principal,
    badge-id: uint,
  }
  {
    earned-timestamp: uint,
    linked-record: (optional uint),
  }
)

(define-map observed-object-diversity
  {
    astronomer: principal,
    object-type: (string-utf8 50),
  }
  { observation-count: uint }
)

(define-data-var next-record-id uint u1)
(define-data-var next-badge-id uint u1)

;; =========================================================
;; Private Functions
;; =========================================================
(define-private (get-observation-count (address principal))
  (default-to u0
    (get total-observations (map-get? observer-profiles { address: address }))
  )
)

(define-private (get-verification-count (address principal))
  (default-to u0
    (get total-verifications (map-get? observer-profiles { address: address }))
  )
)

(define-private (update-object-type-tracking
    (observer principal)
    (object-type (string-utf8 50))
  )
  (let ((current-entry (map-get? observed-object-diversity {
      astronomer: observer,
      object-type: object-type,
    })))
    (match current-entry
      existing-entry 
        (map-set observed-object-diversity {
          astronomer: observer,
          object-type: object-type,
        } { observation-count: (+ (get observation-count existing-entry) u1) })
      
      (map-set observed-object-diversity {
        astronomer: observer,
        object-type: object-type,
      } { observation-count: u1 })
    )
  )
)

(define-private (award-achievement-badge
    (astronomer principal)
    (badge-id uint)
    (linked-record (optional uint))
  )
  (if (has-badge astronomer badge-id)
    false
    (map-set astronomer-badge-collection {
      astronomer: astronomer,
      badge-id: badge-id,
    } {
      earned-timestamp: block-height,
      linked-record: linked-record,
    })
  )
)

(define-private (has-badge
    (astronomer principal)
    (badge-id uint)
  )
  (is-some (map-get? astronomer-badge-collection {
    astronomer: astronomer,
    badge-id: badge-id,
  }))
)

(define-private (check-observer-tier-badge (astronomer principal))
  (let ((observation-count (get-observation-count astronomer)))
    (if (>= observation-count u5)
      (award-achievement-badge astronomer u1 none)
      false
    )
  )
)

(define-private (check-cosmic-explorer-badge (astronomer principal))
  ;; Placeholder for more complex badge logic
  false
)

(define-private (trigger-achievement-checks (astronomer principal))
  (begin
    (check-observer-tier-badge astronomer)
    (check-cosmic-explorer-badge astronomer)
    true
  )
)

;; Rest of the contract will be continued in the next step
;; =========================================================
;; Read-Only Functions
;; =========================================================
(define-read-only (get-observer-profile (address principal))
  (map-get? observer-profiles { address: address })
)

(define-read-only (get-cosmic-record (record-id uint))
  (map-get? cosmic-records { record-id: record-id })
)

(define-read-only (is-record-verified-by
    (record-id uint)
    (verifier principal)
  )
  (default-to false
    (get is-verified
      (map-get? verification-log {
        record-id: record-id,
        verifier: verifier,
      })
    )
  )
)

(define-read-only (get-achievement-badge (badge-id uint))
  (map-get? achievement-badges { badge-id: badge-id })
)

(define-read-only (get-astronomer-badge
    (astronomer principal)
    (badge-id uint)
  )
  (map-get? astronomer-badge-collection {
    astronomer: astronomer,
    badge-id: badge-id,
  })
)

(define-read-only (get-object-type-observations
    (astronomer principal)
    (object-type (string-utf8 50))
  )
  (default-to { observation-count: u0 }
    (map-get? observed-object-diversity {
      astronomer: astronomer,
      object-type: object-type,
    })
  )
)

;; =========================================================
;; Public Functions
;; =========================================================
(define-public (register-observer (username (string-utf8 50)))
  (let ((sender tx-sender))
    (asserts! (> (len username) u0) (err ERR-INVALID-INPUT))
    
    (map-set observer-profiles { address: sender } {
      username: username,
      registration-timestamp: block-height,
      total-observations: u0,
      total-verifications: u0,
    })
    
    ;; Award initial "First Light" badge
    (award-achievement-badge sender u0 none)
    
    (ok true)
  )
)

(define-public (record-cosmic-observation
    (celestial-target (string-utf8 100))
    (object-classification (string-utf8 50))
    (right-ascension (string-utf8 20))
    (declination (string-utf8 20))
    (location (string-utf8 100))
    (atmospheric-conditions (string-utf8 50))
    (meteorological-data (string-utf8 100))
    (equipment-details (string-utf8 200))
    (observer-notes (string-utf8 500))
    (evidence-signature (optional (buff 32)))
  )
  (let (
      (sender tx-sender)
      (record-id (var-get next-record-id))
    )
    ;; Validate input parameters
    (asserts! 
      (and 
        (> (len celestial-target) u0) 
        (> (len object-classification) u0)
      )
      (err ERR-INVALID-INPUT)
    )
    
    ;; Store cosmic record
    (map-set cosmic-records { record-id: record-id } {
      observer: sender,
      celestial-target: celestial-target,
      object-classification: object-classification,
      sky-coordinates: {
        right-ascension: right-ascension,
        declination: declination,
      },
      record-timestamp: block-height,
      observation-context: {
        location: location,
        atmospheric-conditions: atmospheric-conditions,
        meteorological-data: meteorological-data,
      },
      equipment-details: equipment-details,
      observer-notes: observer-notes,
      evidence-signature: evidence-signature,
      verification-tally: u0,
    })
    
    ;; Track object type observations
    (update-object-type-tracking sender object-classification)
    
    ;; Check for potential achievements
    (trigger-achievement-checks sender)
    
    ;; Increment record ID counter
    (var-set next-record-id (+ record-id u1))
    
    (ok record-id)
  )
)

(define-public (verify-cosmic-record (record-id uint))
  (let (
      (sender tx-sender)
      (cosmic-record (map-get? cosmic-records { record-id: record-id }))
    )
    ;; Ensure record exists
    (asserts! (is-some cosmic-record) (err ERR-OBSERVATION-INVALID))
    
    (let ((unwrapped-record (unwrap! cosmic-record (err ERR-OBSERVATION-INVALID))))
      ;; Prevent self-verification
      (asserts! (not (is-eq sender (get observer unwrapped-record)))
        (err ERR-UNAUTHORIZED-ACTION)
      )
      
      ;; Check for duplicate verification
      (asserts! (not (is-verified-by record-id sender))
        (err ERR-DUPLICATE-VERIFICATION)
      )
      
      ;; Log verification
      (map-set verification-log {
        record-id: record-id,
        verifier: sender,
      } { is-verified: true })
      
      ;; Update record's verification tally
      (map-set cosmic-records { record-id: record-id }
        (merge unwrapped-record { 
          verification-tally: (+ (get verification-tally unwrapped-record) u1) 
        })
      )
      
      ;; Award "Community Validator" badge if record gets 10 verifications
      (if (is-eq (+ (get verification-tally unwrapped-record) u1) u10)
        (award-achievement-badge 
          (get observer unwrapped-record) 
          u4 
          (some record-id)
        )
        false
      )
      
      ;; Award "Verification Expert" badge
      (if (is-eq (+ (get-verification-count sender) u1) u10)
        (award-achievement-badge sender u5 none)
        false
      )
      
      (ok true)
    )
  )
)

(define-public (create-achievement-badge
    (badge-name (string-utf8 50))
    (badge-description (string-utf8 200))
    (badge-criteria (string-utf8 200))
    (badge-rarity (string-utf8 20))
  )
  (let (
      (sender tx-sender)
      (badge-id (var-get next-badge-id))
    )
    ;; Only contract owner can create badges
    (asserts! (is-eq sender tx-sender) (err ERR-UNAUTHORIZED-ACTION))
    
    ;; Store badge details
    (map-set achievement-badges { badge-id: badge-id } {
      badge-name: badge-name,
      badge-description: badge-description,
      badge-criteria: badge-criteria,
      badge-rarity: badge-rarity,
    })
    
    ;; Increment badge ID counter
    (var-set next-badge-id (+ badge-id u1))
    
    (ok badge-id)
  )
)
