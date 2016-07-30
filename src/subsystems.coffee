# Author: maartyl

# I will need:
# @inject : info about what it requires (nothing more)
# @system : provides :start which toposorts and starts all subsystems
# @start function :: System -> It'sAPI (generally map of started subsystems)
#
#
# solve problem of defining deps on this system
# HAS TO BE EXPLICIT ^
#
# and cont gets map of all the started subsystems
#
# systems goes through all objects and asks:
# Hey, mate, are you an inject? and if so, it's a dependency.
# : how do I put such injects on this system itself? ...
# - maybe the most simple way: just provide inject, instead of subsystem, yeah...
# - I like this and I'm pretty sure it will work ^^
# //since all must be resolved, before start is called.
#
# each system has to provide everything for his subs, even if all he can do is explicitly state he needs it.
#
# if a dependency CANNOT BE FOUND: must produce nice error
# if a CYCLIC dependency is found: must produce nice error
#
# how will I perform the INJECTION ITSELF?
# : all 'done' store in a map
# : keep info who needs what: take from the map, before calling start
# -- (Will be there by the time it's needed; if not: missing dependency (would probably notice in toposort anyway))
# : keep 'meta' who needs what, though. (should be a function! (for simplicity, composability...))
# -- and THAT FUNCTION CAN JUST END WITH CALLING START, having everything ordered implicitly
# -- takes rest of initialization as argument... - all async and good ^^
#
# let's call that: next(started, cont)   (== inject + call start)
# : this function itself probably needs current context (loaded deps map; what to call at end; sorted deps...)
#
# NO DEPENDENCY CAN BE CALLED START
#
#
# CONT used by start:: (err, api)->()

topo = require 'toposort'
util = require 'util'

jstr = (o) -> util.inspect o, depth:5

isFn = (o) -> typeof o is 'function'

OK = null # passed in error field

class SubsystemInjectorStub
  constructor: (@dep)->@

isInjector = (obj)-> obj instanceof SubsystemInjectorStub

inject = (dependency_name) ->
  if dependency_name is 'start' then throw new Error "No dependency may be called 'start'."
  new SubsystemInjectorStub dependency_name
@inject = inject

# retuns list of dependencies
# [[to from]] (to: which fild to inject) (from: dependency name)
scan = (obj) -> [k, v.dep] for k, v of obj when isInjector v

# get dependencies of a subsystem
# @dependencies = scan #possibly in the future, if needed

# builds edges(dependencies)
# FOR SINGLE NODE name
make_edges = (name, scanned) -> [dep, name] for [field, dep] in scanned

# returns list that can be passed topo (to get order of starting)
# map_subs :: (dependency_name -> subsystem)
# cont :: (err, all_dep_edges, nexts(functions to start component + inject)) -> ()
make_deps = (map_subs, cont) ->
  deps_edges = []
  nexts = {}
  for dep, sub of map_subs
    scanned = scan sub #get all fields with InjectorStub and what they depend on
    deps_edges = deps_edges.concat make_edges dep, scanned #append all dependencies to edges
    unless isFn sub.start
      return cont new Error "Passed subsystem doesn't have start method - #{jstr dep}:#{jstr sub}."

    nexts[dep] = do(dep, scanned, sub, starter=sub.start)-> (started, cont) ->
      sub.start = (cont) -> cont OK, started[dep] #replace start method with just map lookup to cashed result
      if started[dep]? then return cont OK, started[dep] #probably always checked outside, but better safe...

      for [field, sub_dep] in scanned #start_map check doesn't catch some edge cases (unreal dep...)
        unless started[sub_dep]? then return cont new Error "Unmet dependency: #{jstr sub_dep}."
        sub[field] = started[sub_dep] #inject: set field to required from map of started deps
      starter.call sub, cont

  cont OK, deps_edges, nexts

build_context = (nodes, nexts, started, final_cont) ->
  index: 0 #where am I on nodes (which to start next)
  nodes: nodes # toposorted dependency names
  nexts: nexts # functions to start subsystems
  started: started #already started subsystems
  cont: final_cont

execute_context = (cxt) ->
  if cxt.index >= cxt.nodes.length # already started all subsystems
    return cxt.cont OK, cxt.started

  dep = cxt.nodes[cxt.index++]
  if cxt.started[dep]? then return execute_context cxt # already started (needs to be here, not in nexts[])

  #injects + provides api: stored in started and used by following nexts
  cxt.nexts[dep] cxt.started, (err, sub_api) ->
    if err then return cxt.cont err

    cxt.started[dep] = sub_api
    execute_context cxt

# map :: (dependency_name -> subsystem)
# started: (dep_name -> api) #for when this system already depends on another
start_map = (map, started, final_cont) -> make_deps map, (err, deps, nexts) ->
  if err then return final_cont err

  unsorted_nodes = do->(k for k, v of map) # include all nodes (even if unmentioned in depepndencies)
  try nodes = topo.array unsorted_nodes, deps #topologically sort dependency graph
  catch err then return final_cont err #cyclic dependency

  unmets = (jstr dep for dep in nodes when not (nexts[dep]? or started[dep]?))
  if unmets.length isnt 0
    return final_cont new Error "Unmet dependencies: #{unmets}."

  execute_context build_context nodes, nexts, started, final_cont


# @system: something that 'just' composes it, START is what matters
# + keeps track of which deps are met externally (injects) and which need to be started

map2system = (map) ->
  unmet_keys = [] # whether system itself has some :inject values
  met_keys =[]
  for k, v of map
    if isInjector v
      unmet_keys.push k
    else
      met_keys.push k

  map.start = (cont) ->
    started = {}
    unstarted = {}

    for k in unmet_keys
      if isInjector map[k] then cont new Error "System with unmet dependency: #{jstr k}."
      started[k] = map[k]
    for k in met_keys
      unstarted[k] = map[k]

    start_map unstarted, started, cont

  map

# creates subsystem which starts all subsystems in map and passes to
#  cont(of it's start) all APIs produced (with same keys as original subsystems)
# map :: (dependency_name -> subsystem)
@system = (map) ->
  if map.start? then throw new Error "No dependency may be called 'start'."
  map2system map

# this system is assumed to have no unmet dependencies
@start = (system, cont) ->
  s = scan system
  if s.length isnt 0
  then cont new Error "Cannot start system with unmet dependencies: #{jstr dep for [k, dep] in s}."
  else
    unless isFn system.start
    then cont new Error 'No start method on system.'
    else system.start cont


## UTILS

fmap = (dep, fn) -> new class
  value: inject dep
  start: (cont) => # cont OK, fn @value
    try v = fn @value #if fn throws: fail continuation
    catch err then cont err
    cont OK, v

# subsystem which exports some function of it's single dependency
@fmap = fmap
@field = (dep, field) -> fmap dep, (v)->v?[field]

rename = (system, map) ->
  s = scan system
  for [key, old] in s
    system[key] = inject map[old]
  system

# rename dependencies
# MUTATES system ('s injects)
# map (old(inside(require))name -> new(outside)name)
@rename = (system, map) ->
  if map.start? then throw new Error "No dependency may be called 'start'."
  rename system, map

