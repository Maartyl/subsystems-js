
inject = [] # TODO

class Init
  db: inject ':db'
  config: inject ':config'

  start: (cont) =>
    cont @ #this provides the public API of this subsystem

@subsystem = ()-> new Init
