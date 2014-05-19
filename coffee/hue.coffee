fs = require 'fs'

_ = require 'underscore'
hue = require "node-hue-api"
q = require "q"
keypress = require 'keypress'

keypress process.stdin

mod = (n, m) ->
  ((n % m) + m) % m

getUsernameForBridge = (id) ->
  if fs.existsSync('usernames')
    JSON.parse(fs.readFileSync('usernames', {'encoding': 'utf8'}))[id]

getBridge = ->
  hue.locateBridges().then (bridges) ->
    unless bridges.length > 0
      throw new Error('No bridges detected.')
    else
      bridges[0]

getUser = (bridge) ->
  # Get the username associated with this bridge
  username = getUsernameForBridge bridge.id

  if username
    console.log 'Found existing user:', username
    q username
  else
    (new hue.HueApi()).registerUser(bridge.ipaddress).then (username) ->
      bridgeToUsername = if fs.existsSync('usernames') then JSON.parse(fs.readFileSync('usernames', {'encoding': 'utf8'})) else {}
      bridgeToUsername[bridge.id] = username
      fs.writeFileSync('usernames', JSON.stringify(bridgeToUsername))

      console.log 'Registered new user:', username
      username

hslLights = (api, lights, h, s, l) ->
  for light in lights
    console.log 'Setting', light.name, 'to', h, s, l
    api.setLightState light.id, hue.lightState.create().hsl(h, s, l).transition(0.2).on()

toggleWarmWhite = (api, lights) ->
  console.log 'Toggling lights'
  api.lightStatus lights[0].id
    .then (status) ->
      lightsOn = status.state.on
      for light in lights
        if lightsOn
          console.log 'Lights going off'
          api.setLightState light.id, hue.lightState.create().off()
        else
          console.log 'Lights going on'
          api.setLightState light.id, hue.lightState.create().on().white 360, 80

startKeypress = (api, lights) ->
  process.stdin.on 'keypress', (ch, key) ->
    console.log 'Keypress received', ch, key
    if key and key.name and key.name is 'w'
      toggleWarmWhite api, lights

    if key and key.ctrl and key.name == 'c'
      process.stdin.pause()

  process.stdin.setRawMode true
  process.stdin.resume()

getBridge().then (bridge) ->
  getUser(bridge).then (username) ->
    api = new hue.HueApi bridge.ipaddress, username
    api.searchForNewLights().then ->
      api.lights().then (lights) ->
        console.log 'Found lights', lights

        startKeypress api, lights.lights
.done()
