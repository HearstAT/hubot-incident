Helper = require('hubot-test-helper')
#chai = require 'chai'
#sinon = require 'sinon'
#chai.use require 'sinon-chai'

# helper loads a specific script if it's a file
helper = new Helper('./../src/incident/incident.coffee')

#expect = chai.expect
co     = require('co')
expect = require('chai').expect

describe 'incident', ->
  room = null

  beforeEach ->
    room = helper.createRoom(httpd: false)

  # Don't need if you use helper.createRoom(httpd: false) currently
  #afterEach ->
  #  room.destroy()

  it 'compiles', ->
    true

  context 'Show resolved incidents', ->
    beforeEach ->
      room.user.say 'jim', 'hubot incident show resolved'

    it 'should respond no resolved incidents', ->
      expect(room.messages).to.eql [
        ['jim', 'hubot incident show resolved']
        ['hubot', 'No issues currently being tracked with status `resolved`']
      ]

  context 'Show open incidents', ->
    beforeEach ->
      room.user.say 'jim', 'hubot incident show open'

    it 'should respond with no open incidents', ->
      expect(room.messages).to.eql [
        ['jim', 'hubot incident show open']
        ['hubot', "No issues currently being tracked with status `open`"]
      ]

  context 'Resolve incident', ->
    beforeEach ->
      room.user.say 'jim', 'hubot incident resolve 123'

    it 'should respond with that incident is currently not being tracked', ->
      expect(room.messages).to.eql [
        ['jim', 'hubot incident resolve 123']
        ['hubot', 'Issue 123 is not currently being tracked.']
      ]

    #it 'should have the memory set to "this"', ->
    #  brainData = JSON.parse(room.robot.brain.data.toString())
    #  expect(room.robot.brain.data).to.eql {}
