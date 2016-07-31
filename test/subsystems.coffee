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
  it 'has all methods', ->
    expect(s.system).to.exist
    expect(s.inject).to.exist
    expect(s.start).to.exist
    expect(s.field).to.exist
    expect(s.fmap).to.exist
    expect(s.wrap).to.exist
    expect(s.rename).to.exist
    expect(s.subsystem).to.exist
    expect(s.subsystem.async).to.exist
    expect(s.subsystem.ret).to.exist
    expect(s.subsystem.ret.async).to.exist

  it 'creates system', ->
    sys = s.system {}
    expect(sys.start).to.be.a 'function'

  it 'creates subsystem', ->
    sys = do s.subsystem {}, -> do=> #takes different context
      @a = 5
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

    describe 'base subsystem', ->

      it 'simple', system_test expect_ok,
        a: do s.subsystem {}, ->do=> @b=42
        (api) ->
          expect(api).to.have.deep.property 'a.b', 42

      it 'a<s<k', system_test expect_ok,
        a: mk 1
        s: do s.subsystem
          da:'a'
          ->do=> @start= (42 + @da.val) #can export start
        k: s.field 's', 'start'
        (api) ->
          expect(api).to.have.deep.property 's.start', (42+api.a.val)
          expect(api).to.have.deep.property 'k', (42+api.a.val)
          expect(api).to.not.have.deep.property 's.da'

      it 'a<s<k async', system_test expect_ok,
        a: mk 1
        s: do s.subsystem.async
          da:'a'
          (done)->do=>
            @start= (42 + @da.val)
            setTimeout done, 2
        k: s.field 's', 'start'
        (api) ->
          expect(api).to.have.deep.property 's.start', (42+api.a.val)
          expect(api).to.have.deep.property 'k', (42+api.a.val)
          expect(api).to.not.have.deep.property 's.da'

      it 'a<s<k ret', system_test expect_ok,
        a: mk 1
        s: do s.subsystem.ret
          da:'a'
          ->do=> {start: (42 + @da.val)}
        k: s.field 's', 'start'
        (api) ->
          expect(api).to.have.deep.property 's.start', (42+api.a.val)
          expect(api).to.have.deep.property 'k', (42+api.a.val)
          expect(api).to.not.have.deep.property 's.da'

      it 'a<s<k ret.async', system_test expect_ok,
        a: mk 1
        s: do s.subsystem.ret.async
          da:'a'
          (cont)->do=>
            setTimeout (=>cont OK, {start: (42 + @da.val)}), 2
        k: s.field 's', 'start'
        (api) ->
          expect(api).to.have.deep.property 's.start', (42+api.a.val)
          expect(api).to.have.deep.property 'k', (42+api.a.val)
          expect(api).to.not.have.deep.property 's.da'

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

      it 'wrap', system_test expect_ok,
        a: s.wrap 42
        (api) ->
          expect(api).to.have.property 'a', 42

      it 'wrap<b, fmap', system_test expect_ok,
        a: s.wrap 42
        b: mk 8, {da:'a'}
        c: s.fmap 'a', (a) -> a + 8
        (api) ->
          expect(api).to.have.deep.property 'a', 42
          expect(api).to.have.deep.property 'b.val', 8
          expect(api).to.have.deep.property 'b.da', 42
          expect(api).to.have.deep.property 'c', 50

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

      it 'between subsystems', system_test expect_err,
        a: s.system
          ax: s.inject 'x'
          ay: mk 42, {dax:'ax'}
        b: s.system
          bx: mk 12, {dby:'by'}
          by: s.inject 'y'
        x: s.field 'b', 'bx'
        y: s.field 'a', 'ay'
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

    describe 'dependency named start', ->
    
      it 'system', ->
        fn = -> s.system start: mk 42, {}
        expect(fn).to.throw Error, /called \'start\'/

      it 'subsystem', ->
        fn = -> s.subsystem start: 'dep', ->0
        expect(fn).to.throw Error, /called \'start\'/
        fn = -> do s.subsystem ok: 'start', ->0
        expect(fn).to.throw Error, /called \'start\'/

      it 'inject', ->
        fn = -> mk 42, {da:'start'}
        expect(fn).to.throw Error, /called \'start\'/

      it 'rename from', ->
        fn = -> s.rename (mk 42, {da:'a'}), {start:'b'}
        expect(fn).to.throw Error, /called \'start\'/

      it 'rename to', ->
        fn = -> s.rename (mk 42, {da:'a'}), {a:'start'}
        expect(fn).to.throw Error, /called \'start\'/

      it 'fmap', ->
        fn = -> s.field 'start', 'start_here_is_fine'
        expect(fn).to.throw Error, /called \'start\'/
        fn = -> s.field 'not_start', 'start'
        expect(fn).to.not.throw Error

    describe 'starting', ->

      it 'misses start method', ->
        cont = (err) -> if err then throw err
        fn = -> s.start {not_a_start:5}, cont
        expect(fn).to.throw Error, /No start method on system/
        fn = -> s.start {start:5}, cont # not a fn
        expect(fn).to.throw Error, /No start method on system/
        fn = -> s.start {}, cont
        expect(fn).to.throw Error, /No start method on system/

      it 'unmet dependencies', system_test expect_err,
        a: s.inject 'unmet_dep'
        (err) -> do(fn=->throw err)->
          expect(fn).to.throw Error, /unmet dependencies/

