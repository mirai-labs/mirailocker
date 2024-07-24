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

    public struct LOCKER has drop {}

    public struct Locker has key {
        id: UID,
        created_at: u64,
        item_count: u8,
        items: VecMap<ID, TypeName>,
        key_id: Option<ID>,
    }

    public struct LockerCreatedEvent has copy, drop {
        locker_id: ID,
        key_id: ID,
    }

    public struct LockerDestroyedEvent has copy, drop {
        locker_id: ID,
    }

    public struct LockedItemAddedEvent has copy, drop {
        locker_id: ID,
        item_id: ID,
        item_type: TypeName,
    }

    public struct LockedItemRemovedEvent has copy, drop {
        locker_id: ID,
        item_id: ID,
        item_type: TypeName,
    }

    const MAX_ITEM_COUNT: u8 = 255;

    const EInvalidKeyForLocker: u64 = 1;

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

        transfer::public_transfer(display, ctx.sender());
        transfer::public_transfer(publisher, ctx.sender());
    }

    public fun new(
        clock: &Clock,
        ctx: &mut TxContext,
    ): Key {
        let mut locker = Locker {
            id: object::new(ctx),
            created_at: clock.timestamp_ms(),
            key_id: option::none(),
            item_count: 0,
            items: vec_map::empty(),
        };

        let key = key::new(
            locker.id(),
            ctx,
        );
        locker.key_id.fill(key.id());

        event::emit(
            LockerCreatedEvent {
                locker_id: locker.id(),
                key_id: key.id(),
            }
        );

        transfer::share_object(locker);

        key
    }

    public fun add_item<T: key + store>(
        key: &Key,
        locker: &mut Locker,
        item: T,
    ) {
        assert_valid_key(key, locker);
        assert!(locker.item_count < MAX_ITEM_COUNT, 1);
        assert!(type_name::get<T>() != type_name::get<Key>(), 1);

        event::emit(
            LockedItemAddedEvent {
                locker_id: locker.id(),
                item_id: object::id(&item),
                item_type: type_name::get<T>(),
            }
        );

        locker.items.insert(object::id(&item), type_name::get<T>());
        locker.item_count = locker.item_count + 1;
        transfer::public_transfer(item, locker.id.to_address());
    }

    public fun remove_item<T: key + store>(
        key: &Key,
        locker: &mut Locker,
        item_to_receive: Receiving<T>,
    ): T {
        assert_valid_key(key, locker);
        
        locker.items.remove(&item_to_receive.receiving_object_id());
        locker.item_count = locker.item_count - 1;

        event::emit(
            LockedItemRemovedEvent {
                locker_id: locker.id(),
                item_id: item_to_receive.receiving_object_id(),
                item_type: type_name::get<T>(),
            }
        );

        transfer::public_receive(&mut locker.id, item_to_receive)
    }

    public fun destroy_empty(
        key: Key,
        locker: Locker,
    ) {
        assert_valid_key(&key, &locker);

        event::emit(
            LockerDestroyedEvent {
                locker_id: locker.id(),
            }
        );

        let Locker {
            id,
            created_at: _,
            item_count: _,
            items,
            key_id: _,
        } = locker;

        items.destroy_empty();
        id.delete();

        key.drop();
    }

    fun id(
        locker: &Locker,
    ): ID {
        object::id(locker)
    }
    
    fun assert_valid_key(
        key: &Key,
        locker: &Locker,
    ) {
        assert!(key.locker_id() == locker.key_id.borrow(), EInvalidKeyForLocker);
    }
}

