;; ------------------------------------------------------------
;; SkillVault Protocol - Decentralized Skill Certification System
;; Functionality Name: decentralized-skill-verifier
;; Author: [Your Name]
;; License: MIT
;; ------------------------------------------------------------

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_VERIFIED (err u102))
(define-constant ERR_MINT_FAILED (err u103))

(define-data-var contract-owner principal tx-sender)
(define-data-var certificate-counter uint u0)

(define-map institutions principal bool)

(define-map certificates
  uint
  {
    learner: principal,
    institution: principal,
    skill: (string-ascii 100),
    level: (string-ascii 30),
    verified: bool
  }
)

;; Fungible Token for Rewarding Learners
(define-fungible-token skill-token)

;; ------------------------------------------------------------
;; (1) Institution Registration
(define-public (register-institution (account principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set institutions account true)
    (ok "Institution successfully registered")
  )
)

;; ------------------------------------------------------------
;; (2) Issue Certificate
;; ------------------------------------------------------------
(define-public (issue-certificate
    (learner principal)
    (skill (string-ascii 100))
    (level (string-ascii 30))
  )
  (begin
    (asserts! (default-to false (map-get? institutions tx-sender)) ERR_UNAUTHORIZED)
    (let ((cert-id (+ (var-get certificate-counter) u1)))
      (map-set certificates cert-id
        {
          learner: learner,
          institution: tx-sender,
          skill: skill,
          level: level,
          verified: false
        }
      )
      (var-set certificate-counter cert-id)
      (ok (tuple (certificate-id cert-id) (status "issued")))
    )
  )
)

;; ------------------------------------------------------------
;; (3) Verify Certificate and Reward
;; ------------------------------------------------------------
(define-public (verify-certificate (cert-id uint))
  (let ((cert (map-get? certificates cert-id)))
    (begin
      (let ((data (unwrap-panic cert)))
        (if (get verified data)
          ERR_ALREADY_VERIFIED
          (let ((set-res (map-set certificates cert-id
                           {
                             learner: (get learner data),
                             institution: (get institution data),
                             skill: (get skill data),
                             level: (get level data),
                             verified: true
                           })))
            (begin
              ;; check that the map-set response succeeded before continuing
              (asserts! set-res ERR_UNAUTHORIZED)
              ;; Mint reward tokens to the learner and check result
              (let ((mint-res (ft-mint? skill-token u100 (get learner data))))
                (begin
                  (asserts! (is-ok mint-res) ERR_MINT_FAILED)
                  (ok (tuple (verified true) (reward u100)))
                )
              )
            )
          )
        )
      )
    )
  )
)

;; ------------------------------------------------------------
;; (4) Read-only Queries
;; ------------------------------------------------------------
(define-read-only (get-certificate (cert-id uint))
  (map-get? certificates cert-id)
)

(define-read-only (get-total-certificates)
  (var-get certificate-counter)
)

(define-read-only (is-institution (account principal))
  (default-to false (map-get? institutions account))
)

