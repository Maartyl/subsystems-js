chai = require 'chai'
expect = chai.expect

util = require 'util'

s = require 'p/subsystems'


OK = null #for err fields

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


catching = (done, fn) ->
  try return done v if (v=fn()) instanceof Error
  catch err then return done(err)
  done OK

expect_ok = (done, extra) ->
  extra = extra or ->OK
  #return callback to .start
  (err, api) -> catching done, ->
    if err then throw err
    extra api





describe 'trivial', ->
  it 'creates system', ->
    sys = s.system {}
#     expect(sys).to.have.property 'start'
    expect(sys.start).to.be.a 'function'

describe 'system', ->
  describe 'working', ->

    it 'simple a', (done) ->
      S = s.system
        a: mk 42, {}
      s.start S, expect_ok done, (api) ->
        expect(api).to.have.deep.property 'a.val', 42

    it 'simple a,b', (done) ->
      S = s.system
        a: mk 42, {}
        b: mk 12, {}
      s.start S, expect_ok done, (api) ->
        expect(api).to.have.deep.property 'a.val', 42
        expect(api).to.have.deep.property 'b.val', 12

    it 'simple a<b', (done) ->
      S = s.system
        a: mk 42, {}
        b: mk 12, {da:'a'}
      s.start S, expect_ok done, (api) ->
        expect(api).to.have.deep.property 'a.val', 42
        expect(api).to.have.deep.property 'b.val', 12
        expect(api).to.have.deep.property 'b.da', api.a




  describe 'broken', -> 0




describe 'util', -> 0
