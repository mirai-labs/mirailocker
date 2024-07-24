// Copyright (c) Studio Mirai, Inc.
// SPDX-License-Identifier: Apache-2.0

module mirailocker::master_key {

    use sui::display::{Self};
    use sui::package;

    public struct MASTER_KEY has drop {}

    public struct MasterKey has key, store {
        id: UID,
        locker_id: ID,
    }

    fun init(
        otw: MASTER_KEY,
        ctx: &mut TxContext,
    ) {
        let publisher = package::claim(otw, ctx);

        let mut display = display::new<MasterKey>(&publisher, ctx);
        display.add(b"name".to_string(), b"MiraiLocker Master Key #{number}".to_string());
        display.add(b"description".to_string(), b"A master key for MiraiLocker #{number}.".to_string());
        display.add(b"number".to_string(), b"{number}".to_string());
        display.add(b"image_url".to_string(), b"https://img.sm.xyz/{id}.webp".to_string());
        display.add(b"locker_id".to_string(), b"{locker_id}".to_string());

        transfer::public_transfer(display, ctx.sender());
        transfer::public_transfer(publisher, ctx.sender());
    }

    public fun drop(
        mkey: MasterKey,
    ) {
        let MasterKey {
            id,
            locker_id: _,
        } = mkey;

        id.delete()
    }

    public(package) fun new(
        locker_id: ID,
        ctx: &mut TxContext,
    ): MasterKey {
        let mkey = MasterKey {
            id: object::new(ctx),
            locker_id: locker_id,
        };

        mkey
    }

    public(package) fun id(
        mkey: &MasterKey,
    ): ID {
        object::id(mkey)
    }

    public(package) fun locker_id(
        mkey: &MasterKey,
    ): ID {
        mkey.locker_id
    }
}