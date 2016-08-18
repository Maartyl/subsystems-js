# Subsystems

Modules are great, but are for functions without state, that don't do anything on their own.

Anything that needs initialization or (dynamic) settings (etc.) is a subsystem.

This extremely simple *dependecy-injection* library provides
a very flexible and cheap way to (asynchronously) compose such subsystems.

I suggest using more feature rich dependency managers for large projects,
but for small or medium sized proejects, this library might be perfectly enough...

## Installation
`npm install subsystems`

## Overview

### Subsystem (contract)
Any object, `obj`, with the following property is accepted as a subsystem:

`obj.start :: (cont)->()`
where `cont :: (err, api)->()`
and `api` being whatever the subsystem wishes to provide to others.
The start method has to invoke the continuation (once).

There's no difference between a system and a subsystem,
other than subsystems being immediate children of the system.

#### Dependencies
In addition to `start` method, a subsystem might have any number of dependencies.

A dependency is defined as any property with value obtained from calling `inject` function:

      obj.db = subsystems.inject('db-dep');

`obj` now depends on `'db-dep'`.

By the time the 'framework' invokes `obj.start` the `obj.db` field will have been set
with the already *started* db provided by another subsystem. (or will report a missing dependency)

//in the above, 'db' and 'db-dep' were just examples and can by
any number of any dependencies (that aren't 'start').

### Functionality
- can start systems
- can compose (dependent) subsystems into a system
- composing of subsystems works recursively
- no external configuration files
- dependencies have to be stated explicitly (per system 'layer')
  - can be stated inside the subsystem to make composing more readable
  - but dependencies can be renamed while composing
    - changes in system don't force changes in subsystems (unless the api changes, of course*)
      - (* but even then, if it can be mapped to the old on, it's easy to achieve that with `fmap`)
- flexible (subsystem is free to provide arbitrary api)

#### Example
Examples are in *CoffeeScript*, to make them as simple to read as possible.
If you are not familiar with CoffeeScript, you can easily
[compile it to JS](http://coffeescript.org/#try:%7Binject%2C%20system%2C%20field%2C%20rename%2C%20start%7D%20%3D%20require%20'subsystems'%0A%0A%23the%20following%20%60sub%60%20vars%20would%20generally%20be%20in%20different%20files%20...%0A%23and%20a%20new%20(mutable)%20subsystem%20would%20be%20created%20each%20time%0A%0Asub_db%20%3D%20new%20class%20%23new%20class%20just%20allows%20me%20to%20reference%20other%20fields%0A%20%20conf%3A%20inject%20'config'%0A%20%20start%3A%20(cont)%20%3D%3E%20load_db_somehow%20%40conf.conn%2C%20%40conf.user%2C%20%40conf.password%2C%20cont%0A%0Asub_config%20%3D%20start%3A%20(cont)%20-%3E%20readJSON%20'config.json'%2C%20cont%0A%0Asub_ctrl%20%3D%20new%20class%0A%20%20db%3A%20inject%20'db'%0A%20%20start%3A%20(cont)%20%3D%3E%20use_db_whatever%20%40db%2C%20cont%0A%0As%20%3D%20system%0A%20%20config%3A%20sub_config%0A%20%20conf_db1%3A%20field%20'config'%2C%20'db1'%0A%0A%20%20db1%3A%20rename%20sub_db%2C%20%7Bconfig%3A'conf_db1'%7D%0A%20%20ctrl%3A%20rename%20sub_ctrl%2C%20%7Bdb%3A'db1'%7D%0Astart%20s%2C%20(err%2C%20api)%20-%3E%0A%20%20if%20err%20then%20return%20handle_err%20err%0A%20%20i_can_use_any_of_above%20api.ctrl%0A).

```coffeescript
{inject, system, field, rename, start, subsystem} = require 'subsystems'

#the following `sub` vars would generally be in different files ...
#and a new (mutable) subsystem would be created each time

sub_db = new class #new class just allows me to reference other fields
  conf: inject 'config'
  start: (cont) => load_db_somehow @conf.conn, @conf.user, @conf.password, cont

sub_config = start: (cont) -> readJSON 'config.json', cont

sub_ctrl = new class
  db: inject 'db'
  start: (cont) => use_db_whatever @db, cont

# common way to define modules supplying subsystems
sub_app = subsystem {db:'db', ctrl:'ctrl'}, ->
  @api_method = ... @db.something ... @ctrl ...

s = system
  config: sub_config
  conf_db1: field 'config', 'db1'

  db1: rename sub_db, {config:'conf_db1'}
  ctrl: rename sub_ctrl, {db:'db1'}
  app: sub_app()
start s, (err, api) ->
  if err then return handle_err err
  i_can_use_any_of_above api.ctrl, api.app.api_method
```

For more details see [API](#api) or for exact details and expectations [tests](test/subsystems.coffee).

### Limitations
- no dependency may be called 'start'
- only provides starting and cannot be used to change anything afterwards
- all subsystems are started 'sequentially'
  - even if some don't depend on each other, they will not be started in 'parallel' (truly asynchronously)
  - if it bugs you, I am planning on making a promise based variant, with `start :: P deps -> P api`
    - I didn't waste time on it, as I doubt I will ever need it*.
      - (promises seem cleaner, but are not as widespread, yet, and I wanted to keep this as lightweiht as possible)
      - (* something starting too slowly and this making it significantly faster)

## API

### `system`
    :: map -> system
    map :: {dependency_name -> subsystem}
    !mutates map
    !throws if map.start

Composes subsystems.

Adds `start` method to `map` which:

- topologically sorts subsystems
- starts them in order
  - resolving dependencies (injects) before calling start of that system
- final system's api is: `{dependency_name -> provided_api}`
- mutates all `inject` properties of subsystems (to appropriate apis)
- replaces all `start` methods with cache lookups
  - this is to assure start is only ever called (exactly) once
  - although, in practice, there should be never a reason to call start methods again

It is possible to supply only `inject` instead of subsystem directly,
which allows for the whole system to have dependencies, but then it cannot be started directly
but instead only used as subsystem.

### `subsystem`
    :: (deps, ctor) -> () -> system
    deps :: {field -> dep_name}
    ctor :: ()->() - updates `this`
    !throws if deps.start or deps.*.start

Creates base subsystem, that doesn't compose any subsystems, but (most likely) defines some dependencies.

Dependencies can be accessed through `this.field_from_deps`.

The api will be created from any changes to `this` in ctor.

#### `subsystem.async`
    :: like subsystem
    ctor :: (done) -> () - updates `this`
    done :: (err?) -> ()

Like `sybsystem`, but asynchronous.

#### `subsystem.ret`
    :: like subsystem
    ctor :: () -> api

Returns api directly, instead of computing it from changes to `this`.

#### `subsystem.ret.async`
    :: like subsystem.ret
    ctor :: (cont) -> ()
    cont :: (err, api) -> ()

Returns api directly and asynchronously, instead of computing it from changes to `this`.

### `inject`
    :: dependency_name -> dependency_descriptor
    !throws if dependency_name == 'start'

Just constructs dependency description, so it can be found on the object.

### `start`
    :: (system, cont)->()

Performs extra checks and invokes `start` method on given `system`, providing given callback `cont`.

The callback receives whatever api the system provides.

This *should only be called once*, at the very 'root' of the application;
to start it after all components (subsystems) have been correctly provided
and 'required' by the other subsystems.

### `rename`
    :: (system, map) -> system
    map :: {inner_dep_name -> outer_dep_name}
    !mutates system
    !throws if (ANY map.*) 'start' in [inner_dep_name, outer_dep_name]

Improves change locality.

All subsystems should have dependecy names that make the most sense in that subsystem.
This means that system and subsystem use different name to describe the same dependency.
To connect them, one has to describe which pair together.

#### example
```javascript
var sub_foo = {
  db: inject('db'),
  start: ...
};

var s = system({
  db1: ...
  db2: ...
  db_no_sql: ...
  ...
  foo: rename(sub_foo, {
    db:'db2' //which 'outer' dep (db2) to use for which 'inner' dep (db).
    })
});
```

### `fmap`
    :: (dependency_name, fn) -> system
    fn :: api -> api | throws

Provides a subsystem that is a function of some dependency.

Generally, it's good if subsystems only depend on what they actually need.
This function provides a simple mechanism to create a new dependency that is a 'view' of another.


#### `field`
    :: (dependency_name, field_name) -> system

Common, special variant of `fmap`, with `fn ~= api[field_name]`.

### `wrap`
    :: (obj) -> system

Returns system that provides obj as it's api and has no dependencies.

## Contributing
- more tests are always welcome
- more asynchronous starting would be cool
- feel free to open tickets or write me with any ideas or questions...

---

This library was loosely inspired by [Stuart Sierra's Component](https://youtu.be/13cmHf_kt-Q).
This library is even simpler and does not tackle the immutability problem,
changes of references, nor stopping,
but purely starting subsystems in the correct order and wiring them together.
This is not a dynamic solution. (cannot reflect changes after all systems are started)

[KISS](http://en.wikipedia.org/wiki/KISS_principle)

