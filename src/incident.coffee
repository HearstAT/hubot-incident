# Description:
#  Orderly incident coordination through hubot
#
# Dependencies:
#   "<module name>": "<module version>"
#
# Configuration:
#   HUBOT_INCIDENT_START_CHECKLIST_URL - optional
#   HUBOT_INCIDENT_END_CHECKLIST_URL - optional
#   HUBOT_INCIDENT_PAGERDUTY_SERVICE_EMAIL - should be updated to use HUBOT_PAGERDUTY_USER_ID
# From hubot-pager-me config
#   HUBOT_PAGERDUTY_TEST_EMAIL
#   HUBOT_PAGERDUTY_SUBDOMAIN
#   
# Commands:
#   hubot incident start <pagerduty id> - Manually initiate incident
#   hubot incident end <pagerduty id> - Manually resolve incident
#   hubot incident currently tracking - List out the incidents currently being tracked in the hubot brain
#
# Notes:
#   <optional notes required for the script>
#
# Authors:
#   Aaron Blythe
#   Levi Smith

moment = require('moment')
checklists = require('./documentation/checklist_md')
pagerduty = require('./pagerduty/pagerduty')
pdServiceEmail = process.env.HUBOT_INCIDENT_PAGERDUTY_SERVICE_EMAIL
pdTestEmail = process.env.HUBOT_PAGERDUTY_TEST_EMAIL
incidentRoom              = process.env.HUBOT_INCIDENT_PAGERDUTY_ROOM
# Webhook listener endpoint. Set it to whatever URL you want, and make sure it matches your pagerduty service settings
incidentEndpoint          = process.env.HUBOT_INCIDENT_PAGERDUTY_ENDPOINT || "/incident"


module.exports = (robot) ->
  unless robot.brain.data.openincidents?
    robot.brain.data.openincidents = {}

  robot.respond /incident start (\d+)/i, (msg) ->
    # TODO: work on auth so only the specified users are responded to
    incidentNumber = msg.match[1]
    startIncident(incidentNumber, msg)

  # helper function to show this works, should be removed when debugging is done
  #robot.respond /incident log (\d+)/i, (msg) ->
  #  incidentHash = robot.brain.data.openincidents[msg.match[1]]
  #  msg.send incidentHash['log']

  robot.respond /incident currently tracking/, (msg) ->
    msg.send "hello contents of my brain #{robot.brain.data.openincidents}"
    if robot.brain.data.openincidents.length == 0
      msg.send "No issues currently being tracked"
    for k,v of robot.brain.data.openincidents
      msg.send "Currently tracking PagerDuty Incident #{k} from start time #{robot.brain.data.openincidents[k]['start_time']}"

  robot.respond /incident end (\d+)/i, (msg) ->
    # TODO: work on auth so only authorized users are responded to
    incidentNumber = msg.match[1]
    endIncident(incidentNumber, msg)
  
  robot.respond /incident help/i, (msg) ->
    commands = robot.helpCommands()
    commands = (command for command in commands when command.match(/incident/))
    msg.send commands.join("\n")

  ## TODO: ensure only get the messages from the incident room
  robot.hear /(.+)/, (msg) ->
    for k,v of robot.brain.data.openincidents
      note = "#{getCurrentTime()}  #{msg.message.user.name} #{msg.message.text} \n"
      robot.brain.data.openincidents[k]['log'] += note
      postNoteToPagerDuty(msg,k,note)

  ##### Functions

  # TODO: find a way to remove 'msg'
  startIncident = (incidentNumber, msg) ->
    #is inicident being tracked yet?
    for k,v of robot.brain.data.openincidents
      if k == incidentNumber
        msg.send "incident #{k} is already being tracked"
        return
    incidentHash = buildIncidentHash(incidentNumber)
    robot.brain.data.openincidents[incidentNumber] = incidentHash
    msg.send "INCIDENT NOTIFY: Incident #{incidentNumber} has been started"
    msg.send "Bot has started logging all conversation in this room as of #{robot.brain.data.openincidents[incidentNumber]['start_time']}"
    checklists.getChecklist 'start', (err, content) ->
      if err?
        robot.emit 'error', err, msg
        return
      msg.send formatMarkDown(content)

  # TODO: find a way to remove 'msg'
  endIncident = (incidentNumber, msg) ->
    #is inicident being currently open?
    open = false
    for k,v of robot.brain.data.openincidents
      if k == incidentNumber
        open = true
    if open == false
      msg.send "Issue #{incidentNumber} is not currently being tracked."
      return
    incidentHash = robot.brain.data.openincidents[incidentNumber]
    incidentHash['end_time'] = getCurrentTime()
    duration = calculateDuration(incidentHash['start_time'],incidentHash['end_time'])
    #postNoteToPagerDuty(msg, incidentNumber, incidentHash)
    msg.send "INCIDENT NOTIFY: Resolved incident #{incidentNumber}, Incident duration #{duration}"
    checklists.getChecklist 'end', (err, content) ->
      if err?
        robot.emit 'error', err, msg
        return
      msg.send formatMarkDown(content)

    delete robot.brain.data.openincidents[incidentNumber]

  buildIncidentHash = (incidentNumber) ->
    incidentHash = {}
    incidentHash['start_time'] = getCurrentTime()
    incidentHash['end_time'] = ""
    incidentHash['log'] = ""
    incidentHash

  formatMarkDown = (content) ->
    block = "```\n"
    block += content
    block += "```\n"
    block

  ##### Pager Duty interaction
  getPagerDutyServiceUser = (msg, required, cb) ->
    if typeof required is 'function'
      cb = required
      required = true
      email  = pdServiceEmail || pdTestEmail
    pagerduty.get "/users", {query: email}, (err, json) ->
      if err?
        robot.emit 'error', err, msg
        return

      if json.users.length isnt 1
        if json.users.length is 0 and not required
          cb null
          return
        else
          msg.send "Sorry, I expected to get 1 user back for #{email}, but got #{json.users.length} :sweat:. If your PagerDuty email is not #{email} use `/pager me as #{email}`"
          return

      cb(json.users[0])

  postNoteToPagerDuty = (msg, incidentNumber, note) ->
    if pagerduty.missingEnvironmentForApi(msg)
      #TODO: error handling
      msg.send "PagerDuty setup needs work."
    else
      getPagerDutyServiceUser msg, (user) ->
        userId = user.id
        return unless userId

        data =
          note:
            content: note
          requester_id: userId

        pagerduty.post "/incidents/#{incidentNumber}/notes", data, (err, json) ->
          if err?
            robot.emit 'error', err, msg
            return

          #if json && json.note
          #  msg.send "Transcript of room added to Pagerduty note since #{incidentHash['start_time']}"
          #else
          #  msg.send "Sorry, could not add transcript of room to PagerDuty as note."

  ##### Moment calculations
  calculateDuration = (start, end) ->
    Math.floor(moment.duration(moment(end,"YYYYMMDDTHHmmss").diff(moment(start,"YYYYMMDDTHHmmss"))).asHours())+moment.utc(moment(end,"YYYYMMDDTHHmmss").diff(moment(start,"YYYYMMDDTHHmmss"))).format(":mm:ss")
  
  getCurrentTime = () ->
    now = moment()
    time = now.format('YYYY-MM-DD HH:mm:ss Z')
