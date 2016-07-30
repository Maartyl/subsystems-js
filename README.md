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

### Functionality

#### Examples

### Limitations

## API

### `system`

### `inject`

### `start`

### `rename`

### `fmap`

#### `field`

---

This library was inspired by [Stuart Sierra's Component](https://youtu.be/13cmHf_kt-Q).
This library is even simpler and does not tackle the immutability problem,
changes of references, nor stopping,
but purely starting subsystems in the correct order and wiring them together.
This is not a dynamic solution. (cannot reflect changes after all systems are started)

[KISS](http://en.wikipedia.org/wiki/KISS_principle)

