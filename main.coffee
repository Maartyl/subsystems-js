

# I will need:
# @inject : info about what it requires (nothing more)
# @system : provides :start which toposorts and starts all subsystems
# @start function :: System -> It'sAPI (generally map of started subsystems)
#
#
#
# SOLVE PROBLEM OF DEFINING DEPS ON THIS SYSTEM
# all unmet? ... sounds legit, although... probably not known recursively...
#
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
# etc.
#
# ANOTHER Q: how will I perform the injection itself?
# : all 'done' store in a map
# : keep info who needs what: take from the map, before calling start
# -- (Will be there by the time it's needed; if not: missing dependency (would probably notice in toposort anyway))
# : keep 'meta' who needs what, though. (should be a function! (for simplicity, composability...))
# -- and THAT FUNCTION CAN JUST END WITH CALLING START, having everything ordered implicitly
# -- takes rest of initialization as argument... - all async and good ^^
#
# let's call that: next(cont)   (== inject + call start)
# : this function itself probably needs current context (loaded deps map; what to call at end; sorted deps...)
#
# NO DEPENDENCY CAN BE CALLED START
#
#
# CONT used by start:: (err, api)->()

topo = require 'toposort'

OK = null # passed in error field

class SubsystemInjectorStub
  constructor: (@dep)->@

isInjector = (obj)-> obj instanceof SubsystemInjectorStub

inject = (dependency_name) -> new SubsystemInjectorStub dependency_name
@inject = inject

# retuns list of dependencies
# [[to from]] (to: which fild to inject) (from: dependency name)
scan = (obj) -> [[k, v.dep] for k, v of obj when isInjector v]

# builds edges(dependencies) for this part of graph
# FOR SINGLE NODE
make_edges = (name, scanned) -> [[dep name] for [field, dep] in scanned]

# returns list that can be passed topo (to get order of starting)
# map_subs :: (dependency_name -> subsystem)
# cont :: (err, all_dep_edges, nexts(functions to start component + inject)) -> ()
make_deps = (map_subs, cont) ->
  deps_edges = []
  nexts = {}
  for dep, sub of map_subs
    if dep is 'start' then continue #ignore the start method

    scanned = scan sub
    deps_edges = deps_edges.concat make_edges dep, scanned
    unless sub.start? and typeof sub.start is 'function'
      cont new Error "passed subsystem doesn't have start method - #{dep}:#{sub}"

    nexts[dep] = do(scanned, sub)-> (started, cont) ->
      for [field, dep] in scanned
        unless started[dep] then return cont new Error "Unmet dependency: #{dep}"
        sub[field] = started[dep] #inject: set field to required from map of started deps
      sub.start cont

  cont OK, deps_edges, nexts

build_context = (nodes, nexts, started, final_cont)->
  index: 0 #where am I on nodes (which to start next)
  nodes: nodes # toposorted dependency names
  nexts: nexts # functions to start subsystems
  started: started #already started subsystems
  cont: final_cont

execute_context = (cxt) ->
  if cxt.index >= cxt.nodes.length # already started all subsystems
    return cxt.final_cont OK, cxt.started

  dep = cxt.nodes[cxt.index++]

  #injects + provides api: stored in started and used by following nexts
  cxt.nexts[dep] cxt.started, (err, sub_api) ->
    if err then return cxt.final_cont err

    cxt.started[dep] = sub_api
    execute_context cxt

# map :: (dependency_name -> subsystem)
# started: (dep_name -> api) #for when this system already depends on another
start_map = (map, started, final_cont) -> make_deps map, (err, deps, nexts) ->
  if err then final_cont err else
    nodes = try topo(edges)
    catch err
      final_cont new Error 'Cyclic dependency: ' + err
    execute_context build_context nodes, nexts, started, final_cont


# @system: somethingthat 'just' composes it, START is what matters


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
      if isInjector map[k] then cont new Error "system with unmet dependency: #{k}"
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
@start = (system, cont) -> start_map _root:system, {}, ({_root}) -> cont _root


## UTILS

fmap = (dep, fn) -> new class
  value: inject dep
  start: (cont) => cont OK, fn @value

# subsystem which exports some function of it's single dependency
@fmap = fmap
@field = (dep, field) -> fmap dep, (v)->v?[field]


#end
