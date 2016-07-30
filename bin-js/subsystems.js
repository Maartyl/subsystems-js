// Generated by CoffeeScript 1.10.0
(function() {
  var OK, SubsystemInjectorStub, build_context, execute_context, fmap, inject, isFn, isInjector, jstr, make_deps, make_edges, map2system, rename, scan, start_map, topo, util,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  topo = require('toposort');

  util = require('util');

  jstr = function(o) {
    return util.inspect(o, {
      depth: 5
    });
  };

  isFn = function(o) {
    return typeof o === 'function';
  };

  OK = null;

  SubsystemInjectorStub = (function() {
    function SubsystemInjectorStub(dep1) {
      this.dep = dep1;
      this;
    }

    return SubsystemInjectorStub;

  })();

  isInjector = function(obj) {
    return obj instanceof SubsystemInjectorStub;
  };

  inject = function(dependency_name) {
    if (dependency_name === 'start') {
      throw new Error("No dependency may be called 'start'.");
    }
    return new SubsystemInjectorStub(dependency_name);
  };

  this.inject = inject;

  scan = function(obj) {
    var k, results, v;
    results = [];
    for (k in obj) {
      v = obj[k];
      if (isInjector(v)) {
        results.push([k, v.dep]);
      }
    }
    return results;
  };

  this.dependencies = scan;

  make_edges = function(name, scanned) {
    var dep, field, i, len, ref, results;
    results = [];
    for (i = 0, len = scanned.length; i < len; i++) {
      ref = scanned[i], field = ref[0], dep = ref[1];
      results.push([dep, name]);
    }
    return results;
  };

  make_deps = function(map_subs, cont) {
    var dep, deps_edges, nexts, scanned, sub;
    deps_edges = [];
    nexts = {};
    for (dep in map_subs) {
      sub = map_subs[dep];
      scanned = scan(sub);
      deps_edges = deps_edges.concat(make_edges(dep, scanned));
      if (!isFn(sub.start)) {
        return cont(new Error("Passed subsystem doesn't have start method - " + (jstr(dep)) + ":" + (jstr(sub)) + "."));
      }
      nexts[dep] = (function(dep, scanned, sub, starter) {
        return function(started, cont) {
          var field, i, len, ref, sub_dep;
          sub.start = function(cont) {
            return cont(OK, started[dep]);
          };
          if (started[dep] != null) {
            return cont(OK, started[dep]);
          }
          for (i = 0, len = scanned.length; i < len; i++) {
            ref = scanned[i], field = ref[0], sub_dep = ref[1];
            if (started[sub_dep] == null) {
              return cont(new Error("Unmet dependency: " + (jstr(sub_dep)) + "."));
            }
            sub[field] = started[sub_dep];
          }
          return starter.call(sub, cont);
        };
      })(dep, scanned, sub, sub.start);
    }
    return cont(OK, deps_edges, nexts);
  };

  build_context = function(nodes, nexts, started, final_cont) {
    return {
      index: 0,
      nodes: nodes,
      nexts: nexts,
      started: started,
      cont: final_cont
    };
  };

  execute_context = function(cxt) {
    var dep;
    if (cxt.index >= cxt.nodes.length) {
      return cxt.cont(OK, cxt.started);
    }
    dep = cxt.nodes[cxt.index++];
    if (cxt.started[dep] != null) {
      return execute_context(cxt);
    }
    return cxt.nexts[dep](cxt.started, function(err, sub_api) {
      if (err) {
        return cxt.cont(err);
      }
      cxt.started[dep] = sub_api;
      return execute_context(cxt);
    });
  };

  start_map = function(map, started, final_cont) {
    return make_deps(map, function(err, deps, nexts) {
      var dep, error, nodes, unmets, unsorted_nodes;
      if (err) {
        return final_cont(err);
      }
      unsorted_nodes = (function() {
        var k, results, v;
        results = [];
        for (k in map) {
          v = map[k];
          results.push(k);
        }
        return results;
      })();
      try {
        nodes = topo.array(unsorted_nodes, deps);
      } catch (error) {
        err = error;
        return final_cont(err);
      }
      unmets = (function() {
        var i, len, results;
        results = [];
        for (i = 0, len = nodes.length; i < len; i++) {
          dep = nodes[i];
          if (!((nexts[dep] != null) || (started[dep] != null))) {
            results.push(jstr(dep));
          }
        }
        return results;
      })();
      if (unmets.length !== 0) {
        return final_cont(new Error("Unmet dependencies: " + unmets + "."));
      }
      return execute_context(build_context(nodes, nexts, started, final_cont));
    });
  };

  map2system = function(map) {
    var k, met_keys, unmet_keys, v;
    unmet_keys = [];
    met_keys = [];
    for (k in map) {
      v = map[k];
      if (isInjector(v)) {
        unmet_keys.push(k);
      } else {
        met_keys.push(k);
      }
    }
    map.start = function(cont) {
      var i, j, len, len1, started, unstarted;
      started = {};
      unstarted = {};
      for (i = 0, len = unmet_keys.length; i < len; i++) {
        k = unmet_keys[i];
        if (isInjector(map[k])) {
          cont(new Error("System with unmet dependency: " + (jstr(k)) + "."));
        }
        started[k] = map[k];
      }
      for (j = 0, len1 = met_keys.length; j < len1; j++) {
        k = met_keys[j];
        unstarted[k] = map[k];
      }
      return start_map(unstarted, started, cont);
    };
    return map;
  };

  this.system = function(map) {
    if (map.start != null) {
      throw new Error("No dependency may be called 'start'.");
    }
    return map2system(map);
  };

  this.start = function(system, cont) {
    var dep, k, s;
    s = scan(system);
    if (s.length !== 0) {
      return cont(new Error("Cannot start system with unmet dependencies: " + ((function() {
        var i, len, ref, results;
        results = [];
        for (i = 0, len = s.length; i < len; i++) {
          ref = s[i], k = ref[0], dep = ref[1];
          results.push(jstr(dep));
        }
        return results;
      })()) + "."));
    } else {
      if (!isFn(system.start)) {
        return cont(new Error('No start method on system.'));
      } else {
        return system.start(cont);
      }
    }
  };

  fmap = function(dep, fn) {
    return new ((function() {
      function _Class() {
        this.start = bind(this.start, this);
      }

      _Class.prototype.value = inject(dep);

      _Class.prototype.start = function(cont) {
        var err, error, v;
        try {
          v = fn(this.value);
        } catch (error) {
          err = error;
          cont(err);
        }
        return cont(OK, v);
      };

      return _Class;

    })());
  };

  this.fmap = fmap;

  this.field = function(dep, field) {
    return fmap(dep, function(v) {
      return v != null ? v[field] : void 0;
    });
  };

  rename = function(system, map) {
    var i, key, len, old, ref, s;
    s = scan(system);
    for (i = 0, len = s.length; i < len; i++) {
      ref = s[i], key = ref[0], old = ref[1];
      system[key] = inject(map[old]);
    }
    return system;
  };

  this.rename = function(system, map) {
    if (map.start != null) {
      throw new Error("No dependency may be called 'start'.");
    }
    return rename(system, map);
  };

}).call(this);

//# sourceMappingURL=subsystems.js.map
