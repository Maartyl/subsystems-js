s = require './main.js'
util = require 'util'

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
e2 =
  x: 80


d.start = (cont) -> cont OK, d
e.start = (cont) -> cont OK, e
e2.start = (cont) -> cont OK, e2


S1 = -> s.system
  a: a
  b: b
  c: c

#unmet dependency
S2 = -> s.system
#   b: b
  c: c

S3 = -> s.system
  a: a
  b: b
  c: c
  d: d
  e: e

# cyclic + unmet
S4 = -> s.system
  d: d
  e: e


S5 = -> s.system
  c: S1()
  d: d
  e: e2

S6 = -> s.system
  s1: S1()
  c: s.field 's1', 'c'
  d: d
  e: e2

# system with external dependencies
S22 = -> s.system
  a: s.inject 'ka'
  b: s.inject 'kb'
  c: c

S7 = -> s.system
  ka: a
  kb: b
  s2: S22()
  q: s.field 's2', 'c'

s.start S7(), (err, api) ->
  console.log 'final:err:', err
  console.log 'final:api:', util.inspect api, depth:null, colors:true


