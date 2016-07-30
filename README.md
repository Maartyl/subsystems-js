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

#### Examples

### Limitations

## API

### `system`
`:: map -> system`

### `inject`
`:: dependency_name -> dependency_descriptor`

### `start`
`:: (system, cont)->()`
Performs some checks and invokes `start` method on given `system`, providing given callback `cont`.

The callback receives whatever api the system provides.

### `rename`
`:: (system, map) -> system`
`map :: {inner_dep_name -> outer_dep_name}`

### `fmap`
`:: (dependency_name, fn) -> system`
`fn :: api -> api`

#### `field`
`:: (dependency_name, field_name) -> system`

---

This library was loosely inspired by [Stuart Sierra's Component](https://youtu.be/13cmHf_kt-Q).
This library is even simpler and does not tackle the immutability problem,
changes of references, nor stopping,
but purely starting subsystems in the correct order and wiring them together.
This is not a dynamic solution. (cannot reflect changes after all systems are started)

[KISS](http://en.wikipedia.org/wiki/KISS_principle)

