(namespace 'free)

(define-keyset "free.happybanana-airdrop-admin-keyset" (read-keyset 'happybanana-airdrop-admin-keyset))

(module happybanana-airdrop GOVERNANCE

    ;; Define governance capability (allow admin only operations)
    (defcap GOVERNANCE ()
        (enforce-keyset "free.happybanana-airdrop-admin-keyset")
    )

    ;; Check if transaction account is account owner
    (defcap ACCOUNT-OWNER (account:string)
        (enforce-guard (at 'guard (coin.details account)))
    )

    (defschema user-schema
        account:string
        has-used:bool
    )

    (defschema whitelist-schema
        account:string
    )

    (deftable users:{user-schema})
    (deftable whitelist:{whitelist-schema})

    (defconst AIRDROP-ACCOUNT 'airdrop-banana-account)  ;; Account containing airdrop funds
    (defconst USER-AIRDROP-AMOUNT 10.0) ;; Max coins that a user can take from the airdrop account

    ;; Check if user account is in whitelist
    (defun check-whitelist:bool (user-account:string)
        (with-default-read whitelist user-account
            { "account": "" }
            { "account":= account }
            (= account "")    
        )
    )

    ;; Get whitelist entries
    (defun get-whitelist ()
        (select whitelist (constantly true))
    )

    ;; Add single user to whitelist
    (defun add-user-to-whitelist (user-account:string)
        (with-capability (GOVERNANCE)
            (if (check-whitelist user-account)
                [
                    (insert whitelist user-account { "account": user-account })
                    (format "Account {} added to whitelist." [user-account])
                ]
                [
                    (format "Account {} is already present in whitelist." [user-account])
                ]
            )
        )
    )

    ;; Set airdrop white-list
    (defun set-whitelist (accounts:list)
        (map (add-user-to-whitelist) accounts)
    )
    
    ;; Check if user has already taken his airdrop
    (defun taken-airdrop (account:string)
        (with-default-read users account
            { "has-used": false }
            { "has-used":= has-used }
            (if (= has-used false)
                [
                    (format "Account {} can still take airdrop." [account]),
                    false
                ]
                [
                    (format "Account {} has already taken the airdrop." [account]),
                    true
                ]
            )
        )
    )
    
    ;; Fund the airdrop account with the desired amount of KDA
    (defun fund-airdrop-account (account:string amount:decimal)
        (with-capability (GOVERNANCE)
            (coin.transfer-create account AIRDROP-ACCOUNT (read-keyset "happybanana-airdrop-admin-keyset") amount)
        )
    )
    
    ;; Allow users to take their airdrop coins (one time only)
    (defun take-airdrop (account:string ks:keyset)
        (with-capability (ACCOUNT-OWNER account)
            (let ((check (check-whitelist account)))
                (enforce (not check) (format "Account {} not on whitelist." [account]))
            )
            (let ((taken (taken-airdrop account)))
                (if (= (at 1 taken) false)
                    [
                        ;; Transfer airdrop from airdrop account to user account
                        (coin.transfer-create AIRDROP-ACCOUNT account ks USER-AIRDROP-AMOUNT)

                        ;; Register the redemtion in the user table
                        (insert users account { "account": account, "has-used": true })

                        ;; Taken-airdrop function result message
                        (format "Airdrop redeemed for account {}" [account])
                    ]
                    [   
                        ;; Taken-airdrop function result message
                        (at 0 taken)
                    ]
                )
            )
        )
    )
)

(if (read-msg "upgrade")
  ["upgrade"]
  [
    (create-table users)
    (create-table whitelist)
    (coin.create-account "airdrop-banana-account" (read-keyset "happybanana-airdrop-admin-keyset"))
  ]
)
