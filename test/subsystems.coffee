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

#erroneous subsystem
mk_err = (err, map) ->
  (mk_base err,
    (o, val) -> 0
    (o) -> o
  )(undefined, map)

a = -> mk 778,  {}
b = -> mk 8,    da:'a'
c = -> mk 42,   da:'a', db:'b'

# circular dependency
d = -> mk 5,    de:'e', dc:'c'
e = -> mk 16,   dd:'d'
e2= -> mk 80,   {}



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

      it 'empty', system_test expect_ok, {},
        (api) -> expect(api).to.eql {}

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


    describe 'subsystems', ->

      it 'a.b', system_test expect_ok,
        a: s.system
          b: mk 42, {}
        (api) ->
          expect(api).to.have.deep.property 'a.b.val', 42

      it 'a.b, a.kc', system_test expect_ok,
        c: mk 12, {}
        a: s.system
          kc: s.inject 'c'
          b: mk 42, {ka:'kc'}
        (api) ->
          expect(api).to.have.deep.property 'a.b.val', 42
          expect(api).to.have.deep.property 'a.kc.val', 12
          expect(api).to.have.deep.property 'a.b.ka.val', 12

      it 'a,b', system_test expect_ok,
        a: s.system
          r: mk 10, {}
          aq: mk 42, {dr:'r'}
        b: s.system
          bq: mk 12, {}
        (api) ->
          expect(api).to.have.deep.property 'a.aq.val', 42
          expect(api).to.have.deep.property 'a.r.val', 10
          expect(api).to.have.deep.property 'b.bq.val', 12
          expect(api).to.have.deep.property 'a.aq.dr.val', 10
          expect(api).to.have.deep.property 'a.aq.dr', api.a.r

      it 'a<b', system_test expect_ok,
        a: s.system
          r: mk 10, {}
          aq: mk 42, {dr:'r'}
        b: s.system
          z: s.inject 'a'
          bq: mk 12, {dz:'z'}
        (api) ->
          expect(api).to.have.deep.property 'a.aq.val', 42
          expect(api).to.have.deep.property 'a.r.val', 10
          expect(api).to.have.deep.property 'b.bq.val', 12
          expect(api).to.have.deep.property 'a.aq.dr.val', 10
          expect(api).to.have.deep.property 'a.aq.dr', api.a.r
          expect(api).to.have.deep.property 'b.z', api.a
          expect(api).to.have.deep.property 'b.bq.dz.aq.dr.val', 10


    describe 'fmap,field,rename', ->

      it 'rename', system_test expect_ok,
        a: mk 42, {}
        b: s.rename (mk 12, {q:'test'}),
          test:'a'
        (api) ->
          expect(api).to.have.deep.property 'b.val', 12
          expect(api).to.have.deep.property 'b.q.val', 42

      it 'field', system_test expect_ok,
        a: mk 42, {}
        b: s.field 'a', 'val' # on dep 'a' access field 'val'
        (api) ->
          expect(api).to.have.deep.property 'a.val', 42
          expect(api).to.have.deep.property 'b', 42

      it 'fmap - replace', system_test expect_ok,
        a: mk 42, {}
        b: s.fmap 'a', (a) -> if a.val is 42 then 1337 else 0
        (api) ->
          expect(api).to.have.deep.property 'a.val', 42
          expect(api).to.have.deep.property 'b', 1337

      it 'field rename', system_test expect_ok,
        a: mk 42, {}
        b: s.rename (s.field 'test', 'val'),
          test:'a'
        (api) ->
          expect(api).to.have.deep.property 'a.val', 42
          expect(api).to.have.deep.property 'b', 42

      it 'subsystem field rename', system_test expect_ok,
        a: s.system
          g: mk 42, {}
        b: s.rename (s.field 'test', 'g'),
          test:'a'
        v: s.field 'b', 'val' # also field of field ^^
        (api) ->
          expect(api).to.have.deep.property 'a.g.val', 42
          expect(api).to.have.deep.property 'b.val', 42
          expect(api).to.have.deep.property 'v', 42



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

    describe 'cyclic dependencies', ->

      it 'a<>b', system_test expect_err,
        a: mk 42, {db:'b'}
        b: mk 40, {da:'a'}
        (err) ->
          expect(err).to.have.property 'message'
          .and.to.contain 'yclic dependenc' #[Cc]...

      it 'c<a<b<c', system_test expect_err,
        a: mk 42, {db:'c'}
        b: mk 40, {da:'a'}
        c: mk 44, {da:'b'}
        (err) ->
          expect(err).to.have.property 'message'
          .and.to.contain 'yclic dependenc' #[Cc]...

      it 'c<a<b<c, d', system_test expect_err,
        a: mk 42, {db:'c'}
        b: mk 40, {da:'a'}
        c: mk 44, {da:'b'}
        d: mk 13, {dx:'a'}
        (err) ->
          expect(err).to.have.property 'message'
          .and.to.contain 'yclic dependenc' #[Cc]...
          .and.to.not.contain '"d"' #d isn't part of cycle

      it '?<a<>b', system_test expect_err, # cyclic has priority over missing
        a: mk 42, {db:'b', dx:'nonexistent_dep'}
        b: mk 40, {da:'a', dx:'nonexistent_dep2'}
        (err) ->
          expect(err).to.have.property 'message'
          .and.to.contain 'yclic dependenc' #[Cc]...

      it 'a<>a', system_test expect_err,
        a: mk 42, {db:'a'}
        (err) ->
          expect(err).to.have.property 'message'
          .and.to.contain 'yclic dependenc' #[Cc]...

      it 'a<>(b->a)', system_test expect_err,
        a: s.rename (mk 42, {db:'b'}), b:'a'
        (err) ->
          expect(err).to.have.property 'message'
          .and.to.contain 'yclic dependenc' #[Cc]...

    describe 'error while starting subsystem', ->

      it 'a', do(er=new Error)-> system_test expect_err,
        a: mk_err er, {}
        (err) -> expect(err).to.equal er

      it 'a<b', do(er=new Error)-> system_test expect_err,
        a: mk_err er, {}
        b: mk 42, {da:'a'}
        (err) -> expect(err).to.equal er

      it 'e1<e2', do(e1=new Error, e2=new Error)-> system_test expect_err,
        b: mk_err e2, {da:'a'}
        a: mk_err e1, {} #shoould return first error in topo order
        (err) -> expect(err).to.equal e1

      it 'a<er', do(er=new Error)-> system_test expect_err,
        a: mk_err er, {db:'b'}
        b: mk 42, {}
        (err) -> expect(err).to.equal er

