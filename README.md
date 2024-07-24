# MiraiLocker

MiraiLocker is an onchain locker for Sui objects with `key + store` abilities.

MiraiLocker was inspired by the coin lockers in Japanese train stations. MiraiLocker is useful for situations that require multi-object storage locked behind a single object. For example, if you're conducting an onchain auction for multiple items, you can lock the items in MiraiLocker and auction off the key instead of re-implementing the logic for tracking and storing multiple items. MiraiLocker doesn't have built-in Kiosk support at this time, but you can create a separate Kiosk and store its associated `KioskOwnerCap` in a MiraiLocker.

A typical MiraiLocker lifecycle looks like this:

1. The creator creates a new locker, and is issued a master key.
2. The creator uses the master key to add items to the locker.
3. The creators uses the the master key to lock the locker, set a claim expiration deadline, and issue a claim key.
4. The creator sends the claim key to the claimer – this can either be a direct or transfer, or something more complex like an auction.
5. The claimer can claim the items in the locker before the claim expiration deadline.
6. Once a locker is empty, it can be destroyed by anyone.
