s = require './main.js'
util = require 'util'

OK = null

mk = (val, map) ->
  ss = {}
  ss.val = val
  for k, v of map
    ss[k] = s.inject v
  ss.start = (cont) -> cont OK, ss
  ss

a = -> mk 778,  {}
b = -> mk 8,    da:'a'
c = -> mk 42,   da:'a', db:'b'

# circular dependency
d = -> mk 5,    de:'e', dc:'c'
e = -> mk 16,   dd:'d'
e2= -> mk 80,   {}


S1 = -> s.system
  a: a()
  b: b()
  c: c()

#unmet dependency
S2 = -> s.system
#   b: b()
  c: c()

S3 = -> s.system
  a: a()
  b: b()
  c: c()
  d: d()
  e: e()

# cyclic + unmet
S4 = -> s.system
  d: d()
  e: e()


S5 = -> s.system
  c: S1()
  d: d()
  e: e2()

S6 = -> s.system
  s1: S1()
  c: s.field 's1', 'c'
  d: d()
  e: e2()

# system with external dependencies
S72 = -> s.system
  a: s.inject 'ka'
  b: b()
S7 = -> s.system
  ka: a()
  s2: S72()
  q: s.field 's2', 'b'

# rename
S8 = -> s.system
  qa: a()
  b: s.rename b(), a:'qa'

S9 = -> s.system #self cycle + rename
  b: s.rename b(), a:'b'

# cycle through subsystems
# turns out, that to wire it correctly, one needs to create a cycle in the higher level too
SA = -> s.system
  s1: s.system
    a: s.inject 'a'
    b: b()
  s2: s.system
    a: s.rename b(), a:'b'
    b: s.inject 'b'
  a: s.field 's2', 'a'
  b: s.field 's1', 'b'
  c:c()

  
systems = S1:S1, S2:S2, S3:S3, S4:S4, S5:S5, S6:S6, S7:S7, S8:S8, S9:S9, SA:SA

for name, SX of systems
  console.log 'test:', name
  s.start SX(), (err, api) ->
    console.log 'final:err:', err
    console.log 'final:api:', util.inspect api, depth:null, colors:true

console.log 'f', util.inspect SA(), depth:null, colors:true


