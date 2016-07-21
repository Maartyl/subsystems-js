
{inject} = require 'subsystems'

class Init
  db: inject 'db'
  config: inject 'config'

  start: (cont) =>
    cont null, @ #this provides the public API of this subsystem

@subsystem = ()-> new Init


#elsewhere:
subs = require 'subsystems'

s = subs.system
  config: something
  db: require('db...').susbystem()
  xy: require('.').subsystem()

subs.start s, (err, api)->
  #api == {config: ..., db: ..., xy: ...} - all started
  0

