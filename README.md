# MiraiLocker

MiraiLocker is an onchain locker for Sui objects with `key + store` abilities. It was inspired by the coin lockers in Japanese train stations. MiraiLocker is useful for situations that require multi-object storage locked behind a single object. For example, if you're conducting an onchain auction for multiple items, you can lock the items in MiraiLocker and auction off the key instead of re-implementing the logic for tracking and storing multiple items. MiraiLocker doesn't have built-in Kiosk support at this time, but you can create a separate Kiosk and store its associated `KioskOwnerCap` in a MiraiLocker.

* Locker
* Key
* MasterKey
