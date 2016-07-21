s = require './main.js'

OK = null

a =
  x: 5
b =
  da: s.inject 'a'
  y: 8
c =
  da: s.inject 'a'
  db: s.inject 'b'
  z: 42

a.start = (cont) -> cont OK, x:778
b.start = (cont) -> cont OK, b
c.start = (cont) -> cont OK, c


# circular dependency
d =
  de: s.inject 'e'
  dc: s.inject 'c'
  x: 5
e =
  dd: s.inject 'd'
  x: 8


d.start = (cont) -> cont OK, d
e.start = (cont) -> cont OK, e


S1 = s.system
  a: a
  b: b
  c: c

#unmet dependency
S2 = s.system
  b: b
  c: c

S3 = s.system
  a: a
  b: b
  c: c
  d: d
  e: e

# cyclic + unmet
S4 = s.system
  d: d
  e: e

s.start S1, (err, api) ->
  console.log 'final:err:', err
  console.log 'final:api:', api


