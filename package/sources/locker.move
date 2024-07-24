// Copyright (c) Studio Mirai, Inc.
// SPDX-License-Identifier: Apache-2.0

module mirailocker::locker {

    use std::type_name::{Self, TypeName};

    use sui::clock::{Clock};
    use sui::display::{Self};
    use sui::event;
    use sui::package;
    use sui::transfer::{Receiving};
    use sui::vec_map::{Self, VecMap};

    use mirailocker::key::{Self, Key};
    use mirailocker::master_key::{Self, MasterKey};

    public struct LOCKER has drop {}

    public struct Locker has key, store {
        id: UID,
        claim_deadline: Option<u64>,
        creator: address,
        item_count: u8,
        items: VecMap<ID, TypeName>,
        key_id: Option<ID>,
        number: u64,
    }

    public struct LockerCounter has key {
        id: UID,
        count: u64,
    }
    
    public struct LockerCreatedEvent has copy, drop {
        locker_id: ID,
        master_key_id: ID,
    }

    public struct LockerDestroyedEvent has copy, drop {
        locker_id: ID,
    }

    public struct LockerLockedEvent has copy, drop {
        locker_id: ID,
        key_id: ID,
        claim_deadline: u64,
    }

    public struct LockedItemAddedEvent has copy, drop {
        locker_id: ID,
        item_id: ID,
        item_type: TypeName,
        master_key_id: ID,
    }

    public struct LockedItemClaimedEvent has copy, drop {
        locker_id: ID,
        item_id: ID,
        item_type: TypeName,
        key_id: ID,
    }

    public struct LockedItemRemovedEvent has copy, drop {
        locker_id: ID,
        item_id: ID,
        item_type: TypeName,
        master_key_id: ID,
    }

    const MAX_ITEM_COUNT: u8 = 255;

    const EInvalidKeyForLocker: u64 = 1;
    const EInvalidMasterKeyForLocker: u64 = 2;
    const EClaimPeriodExpired: u64 = 3;
    const EClaimPeriodNotExpired: u64 = 4;
    const EKeyAlreadyIssued: u64 = 5;
    const EMaxItemCountReached: u64 = 6;
    const EKeyNotIssued: u64 = 7;

    fun init(
        otw: LOCKER,
        ctx: &mut TxContext,
    ) {
        let publisher = package::claim(otw, ctx);

        let mut display = display::new<Locker>(&publisher, ctx);
        display.add(b"name".to_string(), b"MiraiLocker #{number}".to_string());
        display.add(b"description".to_string(), b"A digital coin locker that contains {item_count} items.".to_string());
        display.add(b"number".to_string(), b"{number}".to_string());
        display.add(b"image_url".to_string(), b"https://img.sm.xyz/{id}.webp".to_string());

        let counter = LockerCounter {
            id: object::new(ctx),
            count: 0,
        };

        transfer::public_transfer(display, ctx.sender());
        transfer::public_transfer(publisher, ctx.sender());
        transfer::share_object(counter);
    }

    /// Create a new locker and issue a master key which can be used to
    /// place items into the locker.
    public fun new(
        counter: &mut LockerCounter,
        ctx: &mut TxContext,
    ): (Locker, MasterKey) {
        counter.count = counter.count + 1;

        let locker = Locker {
            id: object::new(ctx),
            claim_deadline: option::none(),
            creator: ctx.sender(),
            key_id: option::none(),
            item_count: 0,
            items: vec_map::empty(),
            number: counter.count ,
        };

        let mkey = master_key::new(locker.id(), ctx);

        event::emit(
            LockerCreatedEvent {
                locker_id: locker.id(),
                master_key_id: mkey.id(),
            }
        );

        (locker, mkey)
    }

    /// Lock a locker, and optionally specify a claim deadline for the items inside.
    /// This function also issues a key, which can be used to claim items from the locker.
    public fun lock(
        mkey: &MasterKey,
        locker: &mut Locker,
        claim_deadline: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Key {
        assert_valid_master_key(mkey, locker);
        assert!(claim_deadline > clock.timestamp_ms(), 2);

        locker.claim_deadline.fill(claim_deadline);

        let key = key::new(locker.id.to_inner(), ctx);
        locker.key_id.fill(key.id());

        event::emit(
            LockerLockedEvent {
                locker_id: locker.id.to_inner(),
                key_id: key.id(),
                claim_deadline: claim_deadline,
            }
        );

        key
    }

    /// Add an item to the locker with a master key.
    public fun add_item<T: key + store>(
        mkey: &MasterKey,
        locker: &mut Locker,
        item: T,
    ) {
        assert_valid_master_key(mkey, locker);

        // Assert the locker key is none, which means the key hasn't been created.
        // This check is necessary to ensure items are not added after a key has been created.
        assert!(locker.key_id.is_none(), EKeyAlreadyIssued);
        assert!(locker.item_count < MAX_ITEM_COUNT, EMaxItemCountReached);

        event::emit(
            LockedItemAddedEvent {
                locker_id: locker.id(),
                item_id: object::id(&item),
                item_type: type_name::get<T>(),
                master_key_id: mkey.id(),
            }
        );

        locker.items.insert(object::id(&item), type_name::get<T>());
        locker.item_count = locker.items.size() as u8;

        transfer::public_transfer(item, locker.id.to_address());
    }

    /// Remove an item from the locker with a master key.
    /// This function can only be used after the claim period has expired.
    public fun remove_item<T: key + store>(
        mkey: &MasterKey,
        locker: &mut Locker,
        item_to_receive: Receiving<T>,
        clock: &Clock,
    ): T {
        assert_valid_master_key(mkey, locker);
        assert_claim_period_expired(locker, clock);
        
        locker.items.remove(&item_to_receive.receiving_object_id());
        locker.item_count = locker.items.size() as u8;

        event::emit(
            LockedItemRemovedEvent {
                locker_id: locker.id(),
                item_id: item_to_receive.receiving_object_id(),
                item_type: type_name::get<T>(),
                master_key_id: mkey.id(),
            }
        );

        transfer::public_receive(&mut locker.id, item_to_receive)
    }

    /// Claim an item from the locker with a key.
    /// This function can only be used before the claim period has expired.
    public fun claim_item<T: key + store>(
        key: &Key,
        locker: &mut Locker,
        item_to_receive: Receiving<T>,
        clock: &Clock,
    ): T {
        assert_valid_key(key, locker);
        assert_claim_period_not_expired(locker, clock);
        
        locker.items.remove(&item_to_receive.receiving_object_id());
        locker.item_count = locker.items.size() as u8;

        event::emit(
            LockedItemClaimedEvent {
                locker_id: locker.id(),
                item_id: item_to_receive.receiving_object_id(),
                item_type: type_name::get<T>(),
                key_id: key.id(),
            }
        );

        transfer::public_receive(&mut locker.id, item_to_receive)
    }

    public fun set_claim_deadline(
        mkey: &MasterKey,
        locker: &mut Locker,
        claim_deadline: u64,
    ) {
        assert_valid_master_key(mkey, locker);
        assert!(claim_deadline > *locker.claim_deadline.borrow(), 2);
        locker.claim_deadline.swap(claim_deadline);
    }

    public fun destroy_empty(
        locker: Locker,
        clock: &Clock,
    ) {
        assert_claim_period_expired(&locker, clock);

        event::emit(
            LockerDestroyedEvent {
                locker_id: locker.id(),
            }
        );

        let Locker {
            id,
            claim_deadline: _,
            creator: _,
            item_count: _,
            items,
            key_id: _,
            number: _,
        } = locker;

        items.destroy_empty();
        id.delete();
    }

    fun id(
        locker: &Locker,
    ): ID {
        object::id(locker)
    }

    fun assert_claim_period_not_expired(
        locker: &Locker,
        clock: &Clock,
    ) {
        // Assert the claim key has been issued. If not, it means the claim period
        // has not started yet, which also means it can't expire.
        assert!(locker.key_id.is_some(), EKeyNotIssued);
        if (locker.claim_deadline.is_some()) {
            assert!(*locker.claim_deadline.borrow() > clock.timestamp_ms(), EClaimPeriodExpired);
        };
    }

    fun assert_claim_period_expired(
        locker: &Locker,
        clock: &Clock,
    ) {
        // Assert the claim key has been issued. If not, it means the claim period
        // has not started yet, which also means it can't expire.
        assert!(locker.key_id.is_some(), EKeyNotIssued);
        if (locker.claim_deadline.is_some()) {
            assert!(clock.timestamp_ms() > *locker.claim_deadline.borrow(), EClaimPeriodNotExpired);
        };
    }

    fun assert_valid_key(
        key: &Key,
        locker: &Locker,
    ) {
        assert!(key.locker_id() == locker.key_id.borrow(), EInvalidKeyForLocker);
    }

    fun assert_valid_master_key(
        mkey: &MasterKey,
        locker: &Locker,
    ) {
        assert!(mkey.locker_id() == locker.id(), EInvalidMasterKeyForLocker);
    }
}

