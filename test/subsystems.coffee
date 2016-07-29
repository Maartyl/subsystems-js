chai = require 'chai'
expect = chai.expect

util = require 'util'

s = require 'p/subsystems'


OK = null #for err fields

mk_base = (err, init, fmap) -> (val, map) ->
  ss = {}
  init ss, val
  for k, v of map
    ss[k] = s.inject v
  ss.start = (cont) -> cont err, fmap ss
  ss

mk = mk_base OK,
  (o, val) -> o.val = val
  (o) -> o

a = -> mk 778,  {}
b = -> mk 8,    da:'a'
c = -> mk 42,   da:'a', db:'b'

# circular dependency
d = -> mk 5,    de:'e', dc:'c'
e = -> mk 16,   dd:'d'
e2= -> mk 80,   {}



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

#done: mocha.done
#extra: tests(api)
expect_ok = (done, extra) ->
  extra = extra or ->OK
  #return callback to .start
  (err, api) -> catching done, ->
    if err then throw err
    extra api

#done: mocha.done
#extra: tests(err)
expect_err = (done, extra) ->
  extra = extra or ->OK
  #return callback to .start
  (err, api) -> catching done, ->
    unless err then throw new Error "Missing error (api: #{api})"
    extra err


#variant: expect_ok | expect_err
#sysmap: passed to s.system
#extra: passed to variant
system_test = (variant, sysmap, extra) -> (done) ->
  s.start (s.system sysmap), variant done, extra



describe 'trivial', ->
  it 'creates system', ->
    sys = s.system {}
    expect(sys.start).to.be.a 'function'

describe 'system', ->
  describe 'working', ->
    describe 'simple', ->

      it 'a', system_test expect_ok,
        a: mk 42, {}
        (api) ->
          expect(api).to.have.deep.property 'a.val', 42

      it 'a,b', system_test expect_ok,
        a: mk 42, {}
        b: mk 12, {}
        (api) ->
          expect(api).to.have.deep.property 'a.val', 42
          expect(api).to.have.deep.property 'b.val', 12

      it 'a<b', system_test expect_ok,
        a: mk 42, {}
        b: mk 12, {da:'a'}
        (api) ->
          expect(api).to.have.deep.property 'a.val', 42
          expect(api).to.have.deep.property 'b.val', 12
          expect(api).to.have.deep.property 'b.da', api.a

      it 'a<b<c', system_test expect_ok,
        a: mk 42, {}
        b: mk 12, {da:'a'}
        c: mk 28, {db:'b'}
        (api) ->
          expect(api).to.have.deep.property 'a.val', 42
          expect(api).to.have.deep.property 'b.val', 12
          expect(api).to.have.deep.property 'c.val', 28
          expect(api).to.have.deep.property 'b.da', api.a
          expect(api).to.have.deep.property 'c.db', api.b

      it '(a<b)<c', system_test expect_ok,
        a: mk 42, {}
        b: mk 12, {da:'a'}
        c: mk 28, {da:'a', db:'b'}
        (api) ->
          expect(api).to.have.deep.property 'a.val', 42
          expect(api).to.have.deep.property 'b.val', 12
          expect(api).to.have.deep.property 'c.val', 28
          expect(api).to.have.deep.property 'b.da', api.a
          expect(api).to.have.deep.property 'c.da', api.a
          expect(api).to.have.deep.property 'c.db', api.b
          expect(api).to.have.deep.property 'c.db.da', api.a



    describe 'fmap,field,rename', -> 0
    describe 'subsystems', -> 0

  describe 'broken', ->
    describe 'unmet dependencies', ->

      it 'a', system_test expect_err,
        a: mk 42, {dx:'nonexistent_dep'}
        (err) ->
          expect(err).to.have.property 'message'
          .and.to.contain 'nmet dependenc' #[Uu]nmet c(ies|y)

      it 'a,b', system_test expect_err,
        a: mk 42, {dx:'nonexistent_dep'}
        b: mk 40, {dx:'nonexistent_dep'}
        (err) ->
          expect(err).to.have.property 'message'
          .and.to.contain 'nmet dependenc' #[Uu]nmet c(ies|y)

      it 'a>b', system_test expect_err,
        a: mk 42, {dx:'b'}
        b: mk 40, {dx:'nonexistent_dep'}
        (err) ->
          expect(err).to.have.property 'message'
          .and.to.contain 'nmet dependenc' #[Uu]nmet c(ies|y)


