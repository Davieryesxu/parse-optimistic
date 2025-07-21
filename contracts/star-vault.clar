;; =========================================================
;; STAR-VAULT CONTRACT
;; =========================================================
;; A decentralized registry for amateur astronomers to record
;; and verify astronomical observations permanently on the
;; Stacks blockchain, creating a community-validated archive
;; of celestial discoveries and observations.
;; =========================================================
;; =========================================================
;; Error Constants
;; =========================================================
(define-constant ERR-NOT-REGISTERED u100)
(define-constant ERR-ALREADY-REGISTERED u101)
(define-constant ERR-INVALID-OBSERVATION u102)
(define-constant ERR-NOT-AUTHORIZED u103)
(define-constant ERR-ALREADY-VERIFIED u104)
(define-constant ERR-CANNOT-VERIFY-OWN u105)
(define-constant ERR-BADGE-EXISTS u106)
(define-constant ERR-ACHIEVEMENT-NOT-MET u107)
(define-constant ERR-INVALID-PARAMETERS u108)
;; =========================================================
;; Data Maps and Variables
;; =========================================================
;; Map of registered astronomers
;; Stores basic profile information for registered observers
(define-map astronomers
  { address: principal }
  {
    username: (string-utf8 50),
    registration-time: uint,
    observation-count: uint,
    verification-count: uint,
  }
)
;; Map of astronomical observations
;; Core data structure for storing all celestial observations
(define-map observations
  { id: uint }
  {
    observer: principal,
    celestial-object: (string-utf8 100),
    object-type: (string-utf8 50),
    coordinates: {
      right-ascension: (string-utf8 20),
      declination: (string-utf8 20),
    },
    timestamp: uint,
    conditions: {
      location: (string-utf8 100),
      seeing: (string-utf8 50),
      weather: (string-utf8 100),
    },
    equipment: (string-utf8 200),
    notes: (string-utf8 500),
    evidence-hash: (optional (buff 32)),
    verification-count: uint,
  }
)
;; Map tracking which observers have verified which observations
;; Prevents multiple verifications from the same person
(define-map verifications
  {
    observation-id: uint,
    verifier: principal,
  }
  { verified: bool }
)
;; Map of achievement badges that can be earned
(define-map badges
  { id: uint }
  {
    name: (string-utf8 50),
    description: (string-utf8 200),
    criteria: (string-utf8 200),
    rarity: (string-utf8 20),
  }
)
;; Map tracking which badges each astronomer has earned
(define-map astronomer-badges
  {
    astronomer: principal,
    badge-id: uint,
  }
  {
    earned-at: uint,
    linked-observation: (optional uint),
  }
)
;; Map of different celestial object types observed by each astronomer
;; Used for tracking progress toward certain achievements
(define-map astronomer-object-types
  {
    astronomer: principal,
    object-type: (string-utf8 50),
  }
  { count: uint }
)
;; Counter for observation IDs
(define-data-var next-observation-id uint u1)
;; Counter for badge IDs
(define-data-var next-badge-id uint u1)
;; =========================================================
;; Private Functions
;; =========================================================

;; Get the current observation count for an astronomer
(define-private (get-observation-count (address principal))
  (default-to u0
    (get observation-count (map-get? astronomers { address: address }))
  )
)

;; Get the current verification count for an astronomer
(define-private (get-verification-count (address principal))
  (default-to u0
    (get verification-count (map-get? astronomers { address: address }))
  )
)

;; Update the object type count for an astronomer
(define-private (update-object-type-count
    (observer principal)
    (object-type (string-utf8 50))
  )
  (let ((current-entry (map-get? astronomer-object-types {
      astronomer: observer,
      object-type: object-type,
    })))
    (match current-entry
      existing-entry (map-set astronomer-object-types {
        astronomer: observer,
        object-type: object-type,
      } { count: (+ (get count existing-entry) u1) }
      )
      (map-set astronomer-object-types {
        astronomer: observer,
        object-type: object-type,
      } { count: u1 }
      )
    )
  )
)

;; Check if an astronomer has earned a specific badge
(define-private (has-badge
    (astronomer principal)
    (badge-id uint)
  )
  (is-some (map-get? astronomer-badges {
    astronomer: astronomer,
    badge-id: badge-id,
  }))
)

;; Award a badge to an astronomer
(define-private (award-badge
    (astronomer principal)
    (badge-id uint)
    (observation-id (optional uint))
  )
  (if (has-badge astronomer badge-id)
    false
    (map-set astronomer-badges {
      astronomer: astronomer,
      badge-id: badge-id,
    } {
      earned-at: block-height,
      linked-observation: observation-id,
    })
  )
)

;; Check eligibility for "Observer" badge (5+ observations)
(define-private (check-observer-badge (astronomer principal))
  (let ((observation-count (get-observation-count astronomer)))
    (if (>= observation-count u5)
      (award-badge astronomer u1 none)
      false
    )
  )
)

;; Check eligibility for "Planetary Explorer" badge (observed all planets)
(define-private (check-planetary-explorer-badge (astronomer principal))
  ;; Simplified implementation - in a real contract this would check all planets
  false
)

;; Check all possible badge achievements after a new observation
(define-private (check-achievements (astronomer principal))
  (begin
    (check-observer-badge astronomer)
    (check-planetary-explorer-badge astronomer)
    true
  )
)

;; =========================================================
;; Read-Only Functions
;; =========================================================
;; Get astronomer profile information
(define-read-only (get-astronomer (address principal))
  (map-get? astronomers { address: address })
)

;; Get observation details
(define-read-only (get-observation (id uint))
  (map-get? observations { id: id })
)

;; Check if an observation has been verified by a specific astronomer
(define-read-only (is-verified-by
    (observation-id uint)
    (verifier principal)
  )
  (default-to false
    (get verified
      (map-get? verifications {
        observation-id: observation-id,
        verifier: verifier,
      })
    ))
)

;; Get badge details
(define-read-only (get-badge (id uint))
  (map-get? badges { id: id })
)

;; Get all badges earned by an astronomer
(define-read-only (get-astronomer-badge
    (astronomer principal)
    (badge-id uint)
  )
  (map-get? astronomer-badges {
    astronomer: astronomer,
    badge-id: badge-id,
  })
)

;; Get the number of observations of a specific object type by an astronomer
(define-read-only (get-object-type-count
    (astronomer principal)
    (object-type (string-utf8 50))
  )
  (default-to { count: u0 }
    (map-get? astronomer-object-types {
      astronomer: astronomer,
      object-type: object-type,
    })
  )
)

;; =========================================================
;; Public Functions
;; =========================================================
;; Register as an astronomer in the system
(define-public (register-astronomer (username (string-utf8 50)))
  (let ((sender tx-sender))
    (asserts! (> (len username) u0) (err ERR-INVALID-PARAMETERS))
    (map-set astronomers { address: sender } {
      username: username,
      registration-time: block-height,
      observation-count: u0,
      verification-count: u0,
    })
    ;; Award first badge: "Stargazer" (for registration)
    (award-badge sender u0 none)
    (ok true)
  )
)

;; Record a new astronomical observation
(define-public (record-observation
    (celestial-object (string-utf8 100))
    (object-type (string-utf8 50))
    (right-ascension (string-utf8 20))
    (declination (string-utf8 20))
    (location (string-utf8 100))
    (seeing (string-utf8 50))
    (weather (string-utf8 100))
    (equipment (string-utf8 200))
    (notes (string-utf8 500))
    (evidence-hash (optional (buff 32)))
  )
  (let (
      (sender tx-sender)
      (observation-id (var-get next-observation-id))
    )
    ;; Validate basic parameters
    (asserts! (and (> (len celestial-object) u0) (> (len object-type) u0))
      (err ERR-INVALID-PARAMETERS)
    )
    ;; Store the observation
    (map-set observations { id: observation-id } {
      observer: sender,
      celestial-object: celestial-object,
      object-type: object-type,
      coordinates: {
        right-ascension: right-ascension,
        declination: declination,
      },
      timestamp: block-height,
      conditions: {
        location: location,
        seeing: seeing,
        weather: weather,
      },
      equipment: equipment,
      notes: notes,
      evidence-hash: evidence-hash,
      verification-count: u0,
    })
    ;; Update object type count for achievements
    (update-object-type-count sender object-type)
    ;; Check for any new achievements
    (check-achievements sender)
    ;; Increment the observation ID counter
    (var-set next-observation-id (+ observation-id u1))
    (ok observation-id)
  )
)

;; Verify someone else's observation
(define-public (verify-observation (observation-id uint))
  (let (
      (sender tx-sender)
      (observation (map-get? observations { id: observation-id }))
    )
    ;; Check that the observation exists
    (asserts! (is-some observation) (err ERR-INVALID-OBSERVATION))
    ;; Unwrap the observation
    (let ((unwrapped-observation (unwrap! observation (err ERR-INVALID-OBSERVATION))))
      ;; Check that the verifier is not the original observer
      (asserts! (not (is-eq sender (get observer unwrapped-observation)))
        (err ERR-CANNOT-VERIFY-OWN)
      )
      ;; Check that this verifier hasn't already verified this observation
      (asserts! (not (is-verified-by observation-id sender))
        (err ERR-ALREADY-VERIFIED)
      )
      ;; Record the verification
      (map-set verifications {
        observation-id: observation-id,
        verifier: sender,
      } { verified: true }
      )
      ;; Update verification count on the observation
      (map-set observations { id: observation-id }
        (merge unwrapped-observation { verification-count: (+ (get verification-count unwrapped-observation) u1) })
      )
      ;; If this is the 10th verification, award a special "Community Validated" badge to the observer
      (if (is-eq (+ (get verification-count unwrapped-observation) u1) u10)
        (award-badge (get observer unwrapped-observation) u4
          (some observation-id)
        )
        false
      )
      ;; Check for "Verifier" badge (10+ verifications)
      (if (is-eq (+ (get-verification-count sender) u1) u10)
        (award-badge sender u5 none)
        false
      )
      (ok true)
    )
  )
)

;; Create a new achievement badge (admin only)
(define-public (create-badge
    (name (string-utf8 50))
    (description (string-utf8 200))
    (criteria (string-utf8 200))
    (rarity (string-utf8 20))
  )
  (let (
      (sender tx-sender)
      (badge-id (var-get next-badge-id))
    )
    ;; Only contract owner can create badges - use a proper authorization pattern in production
    (asserts! (is-eq sender tx-sender) (err ERR-NOT-AUTHORIZED))
    ;; Store the badge
    (map-set badges { id: badge-id } {
      name: name,
      description: description,
      criteria: criteria,
      rarity: rarity,
    })
    ;; Increment the badge ID counter
    (var-set next-badge-id (+ badge-id u1))
    (ok badge-id)
  )
)
