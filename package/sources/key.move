// Copyright (c) Studio Mirai, Inc.
// SPDX-License-Identifier: Apache-2.0

module mirailocker::key {

    use sui::display::{Self};
    use sui::package;

    public struct KEY has drop {}

    public struct Key has key, store {
        id: UID,
        locker_id: ID,
    }

    fun init(
        otw: KEY,
        ctx: &mut TxContext,
    ) {
        let publisher = package::claim(otw, ctx);

        let mut display = display::new<Key>(&publisher, ctx);
        display.add(b"name".to_string(), b"MiraiLocker Key #{number}".to_string());
        display.add(b"description".to_string(), b"A key to unlock MiraiLocker #{number}.".to_string());
        display.add(b"number".to_string(), b"{number}".to_string());
        display.add(b"image_url".to_string(), b"https://img.sm.xyz/{id}.webp".to_string());
        display.add(b"locker_id".to_string(), b"{locker_id}".to_string());

        transfer::public_transfer(display, ctx.sender());
        transfer::public_transfer(publisher, ctx.sender());
    }

    public(package) fun new(
        locker_id: ID,
        ctx: &mut TxContext,
    ): Key {
        let key = Key {
            id: object::new(ctx),
            locker_id: locker_id,
        };

        key
    }

    public(package) fun drop(
        key: Key,
    ) {
        let Key {
            id,
            locker_id: _,
        } = key;

        id.delete()
    }

    public(package) fun id(
        key: &Key,
    ): ID {
        object::id(key)
    }

    public(package) fun locker_id(
        key: &Key,
    ): ID {
        key.locker_id
    }
}