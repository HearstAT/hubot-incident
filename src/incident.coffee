# Description:
#  Orderly incident coordination through hubot
#
# Dependencies:
#   "<module name>": "<module version>"
#
# Configuration:
#   HUBOT_INCIDENT_START_CHECKLIST_URL - optional (deprecated will move to dynamic list)
#   HUBOT_INCIDENT_END_CHECKLIST_URL - optional (deprecated will move to dynamic list)
#   HUBOT_INCIDENT_PAGERDUTY_SERVICE_EMAIL - chould be updated to use HUBOT_PAGERDUTY_USER_ID
#   HUBOT_INCIDENT_PAGERDUTY_ROOM - room that the webhooks should go to
#   HUBOT_INCIDENT_PAGERDUTY_ENDPOINT - for webhooks to listen default to '/incident' Set it to whatever URL you want, and make sure it matches your pagerduty service settings
# From hubot-pager-me config
#   HUBOT_PAGERDUTY_TEST_EMAIL
#   HUBOT_PAGERDUTY_SUBDOMAIN
#   
# Commands:
#   hubot incident track <pagerduty id> - Manually initiate incident
#   hubot incident resolve <pagerduty id> - Manually resolve incident
#   incident show (open|resolved|closed) - List out the incidents currently being tracked in the hubot brain by status
#
# Notes:
#   <optional notes required for the script>
#
# Authors:
#   Aaron Blythe
#   Levi Smith

# Dependencies
moment = require('moment')
checklists = require('./documentation/checklist_md')
pagerduty = require('./pagerduty/pagerduty')

# Envrionment Variables
pdServiceEmail   = process.env.HUBOT_INCIDENT_PAGERDUTY_SERVICE_EMAIL
pdTestEmail      = process.env.HUBOT_PAGERDUTY_TEST_EMAIL
incidentRoom     = process.env.HUBOT_INCIDENT_PAGERDUTY_ROOM
incidentEndpoint = process.env.HUBOT_INCIDENT_PAGERDUTY_ENDPOINT || "/incident"


module.exports = (robot) ->
  unless robot.brain.data.incidents?
    robot.brain.data.incidents = {}

  robot.respond /incident track (\d+)/i, (msg) ->
    # TODO: work on auth so only the specified users are responded to
    incidentNumber = msg.match[1]
    trackIncident(incidentNumber, msg)

  # helper function to show this works, should be removed when debugging is done
  robot.respond /incident contents (\d+)/i, (msg) ->
    incidentHash = robot.brain.data.incidents[msg.match[1]]
    data = ""
    for k,v of incidentHash
      data += "#{k}: #{v} \n"
    msg.send data

  robot.respond /incident show (open|resolved|closed)/, (msg) ->
    status = msg.match[1]
    incident_count = 0
    tracking = "Currently tracking: \n"
    if status = "resolved"
      tracking = "Resolved in PagerDuty: \n"
    else if status = "closed"
      tracking = "Closed issues stored in the brain: \n"
    for k,v of robot.brain.data.incidents
      if robot.brain.data.incidents[k]['status'] == status
        tracking += "* PagerDuty Incident `#{k}` from start time `#{robot.brain.data.incidents[k]['start_time']}`\n"
        incident_count += 1
    if incident_count == 0
      msg.send "No issues currently being tracked with status `#{status}`"
    else 
      msg.send tracking

  robot.respond /incident resolve (\d+)/i, (msg) ->
    # TODO: work on auth so only authorized users are responded to
    incidentNumber = msg.match[1]
    resolveIncident(incidentNumber, msg)
  
  robot.respond /incident help/i, (msg) ->
    commands = robot.helpCommands()
    commands = (command for command in commands when command.match(/incident/))
    msg.send commands.join("\n")

  ## TODO: ensure only get the messages from the incident room
  robot.hear /(.+)/, (msg) ->
    for k,v of robot.brain.data.incidents
      if robot.brain.data.incidents[k]['status'] == "open"
        note = "#{getCurrentTime()}  #{msg.message.user.name} #{msg.message.text} \n"
        robot.brain.data.incidents[k]['log'] += note
        postNoteToPagerDuty(msg,k,note)

  ##### Functions

  # TODO: find a way to remove 'msg'
  trackIncident = (incidentNumber, msg) ->
    #is inicident being tracked yet?
    for k,v of robot.brain.data.incidents
      if k == incidentNumber
        msg.send "incident #{k} is already being tracked"
        return
    # Check that incient is open in PagerDuty
    checkIfIncidentOpen msg, incidentNumber, 'triggered,acknowledged', (cb) ->
      if cb == null
        return
      incidentHash = buildIncidentHash(incidentNumber)
      robot.brain.data.incidents[incidentNumber] = incidentHash
      msg.send "INCIDENT NOTIFY: Incident #{incidentNumber} has been is open and is now being tracked."
      msg.send "Bot has started logging all conversation in this room as of #{robot.brain.data.incidents[incidentNumber]['start_time']}"
      checklists.getChecklist 'start', (err, content) ->
        if err?
          robot.emit 'error', err, msg
          return
        msg.send formatMarkDown(content)

  # TODO: find a way to remove 'msg'
  resolveIncident = (incidentNumber, msg) ->
    #is inicident being currently open?
    if robot.brain.data.incidents[incidentNumber]?['status'] != 'open'
      msg.send "Issue #{incidentNumber} is not currently being tracked."
      return
    incidentHash = robot.brain.data.incidents[incidentNumber]
    incidentHash['resolve_time'] = getCurrentTime()
    duration = calculateDuration(incidentHash['start_time'],incidentHash['resolve_time'])
    incidentHash['duration'] = duration
    msg.send "INCIDENT NOTIFY: Resolved incident #{incidentNumber}, Incident duration #{duration}"
    incidentHash['status'] = "resolved"
    checklists.getChecklist 'end', (err, content) ->
      if err?
        robot.emit 'error', err, msg
        return
      msg.send formatMarkDown(content)

    #delete robot.brain.data.incidents[incidentNumber]

  # Store timestamps in epoch (milliseconds from epoch)
  # Store durations in seconds
  # This makes the maths easier later
  # Use moment functions for display
  buildIncidentHash = (incidentNumber) ->
    incidentHash = {}
    # bot known times
    incidentHash['start_time'] = getCurrentTime()
    incidentHash['ack_time']
    incidentHash['resolve_time'] = ""
    incidentHash['unacknowledge_time'] = ""
    incidentHash['assign_time'] = ""
    incidentHash['escalate_time'] = ""
    # pagerduty known times
    incidentHash['pd_trigger_time'] = ""
    incidentHash['pd_ack_time'] = ""
    incidentHash['pd_resolve_time'] = ""
    incidentHash['pd_unacknowledge_time'] = ""
    incidentHash['pd_assign_time'] = ""
    incidentHash['pd_escalate_time'] = ""
    incidentHash['duration'] = ""
    incidentHash['duration_seconds'] = 0
    incidentHash['status'] = "open"
    incidentHash['log'] = ""
    incidentHash

  updateTimestamp = (incidentNumber, type, timestamp) ->
    incidentHash = robot.brain.data.incidents[incidentNumber]
    incidentHash['type'] = timestamp

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

  checkIfIncidentOpen = (msg, incidentNumbers, statusFilter, cb) ->
    pagerduty.getIncidents statusFilter, (err, incidents) ->
      if err?
        robot.emit 'error', err, msg
        cb null
        return

      foundIncidents = []
      for incident in incidents
        # FIXME this isn't working very consistently
        if incidentNumbers.indexOf(incident.incident_number) > -1
          foundIncidents.push(incident)

      if foundIncidents.length == 0
        msg.send "Couldn't find incident(s) #{incidentNumbers}. Use `#{robot.name} pager incidents` for listing. \n Tracking can only be started on unresolved incidents."
        cb null
        return
      else
        cb true
        return

  ##### Moment calculations
  calculateDuration = (start, end) ->
    Math.floor(moment.duration(moment(end,"YYYYMMDDTHHmmss").diff(moment(start,"YYYYMMDDTHHmmss"))).asHours())+moment.utc(moment(end,"YYYYMMDDTHHmmss").diff(moment(start,"YYYYMMDDTHHmmss"))).format(":mm:ss")
  
  getCurrentTime = () ->
    now = moment()
    time = now.format('YYYY-MM-DD HH:mm:ss Z')
