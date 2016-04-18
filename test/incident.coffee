Helper = require('hubot-test-helper')
chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

# helper loads a specific script if it's a file
helper = new Helper('./../src/incident.coffee')

expect = chai.expect

describe 'incident', ->
  room = null

  beforeEach ->
    room = helper.createRoom()

  afterEach ->
    room.destroy()

  it 'compiles', ->
    true


  #context 'An incident is opened with the ID of 123', ->
  #  beforeEach ->
  #    room.user.say 'jim', 'Triggered: Incident #123 (ABC123)'
#
  #  it 'should respond with memorized string', ->
  #    expect(room.messages).to.eql [
  #      ['jim', 'Triggered: Incident #123 (ABC123)']
  #      ['hubot', 'INCIDENT NOTIFY: Incident 123 has been started']
  #      ['hubot', 'Bot has started logging all conversation in this room as of now']
  #    ]
#
  #  it 'should have the memory set to "this"', ->
  #    #brainData = JSON.parse(room.robot.brain.data.toString())
  #    expect(room.robot.brain.data).to.eql {}
