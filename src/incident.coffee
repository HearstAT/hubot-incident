# Description:
#  Orderly incident coordination through hubot
#
# Dependencies:
#   "<module name>": "<module version>"
#
# Configuration:
#
# Notes:
#
# Authors:
#   Aaron Blythe
#   Levi Smith

# Dependencies
moment = require('moment')
checklists = require('./documentation/checklist_md')
pagerduty = require('./pagerduty/pagerduty')

# Envrionment Variables
incidentRoom     = process.env.HUBOT_INCIDENT_PAGERDUTY_ROOM
incidentEndpoint = process.env.HUBOT_INCIDENT_PAGERDUTY_ENDPOINT || "/incident"
pagerDutyUserId  = process.env.HUBOT_PAGERDUTY_USER_ID

##### Functions
module.exports =
  # TODO: find a way to remove 'msg'
  trackIncident: (incidentNumber, msg, robot) ->
    #is inicident being tracked yet?
    for k,v of robot.brain.data.incidents
      if k == incidentNumber
        robot.messageRoom incidentRoom, "incident #{k} is already being tracked"
        return
    # Check that incient is open in PagerDuty
    this.checkIfIncidentOpen msg, incidentNumber, 'triggered,acknowledged', robot, (cb) ->
      if cb == null
        return
      incidentHash = buildIncidentHash(incidentNumber)
      robot.brain.data.incidents[incidentNumber] = incidentHash
      robot.messageRoom incidentRoom, "INCIDENT NOTIFY: Incident #{incidentNumber} has been is open and is now being tracked."
      robot.messageRoom incidentRoom, "Bot has started logging all conversation in this room as of #{robot.brain.data.incidents[incidentNumber]['start_time']}"
      checklists.getChecklist 'start', (err, content) ->
        if err?
          robot.emit 'error', err, msg
          return
        robot.messageRoom incidentRoom, formatMarkDown(content)

  # TODO: find a way to remove 'msg'
  resolveIncident: (incidentNumber, msg, robot) ->
    #is inicident being currently open?
    if robot.brain.data.incidents[incidentNumber]?['status'] != 'open'
      robot.messageRoom incidentRoom, "Issue #{incidentNumber} is not currently being tracked."
      return
    incidentHash = robot.brain.data.incidents[incidentNumber]
    incidentHash['resolve_time'] = this.getCurrentTime()
    duration = this.calculateDuration(incidentHash['start_time'],incidentHash['resolve_time'])
    incidentHash['duration'] = duration
    robot.messageRoom incidentRoom, "INCIDENT NOTIFY: Resolved incident #{incidentNumber}, Incident duration #{duration}"
    incidentHash['status'] = "resolved"
    checklists.getChecklist 'end', (err, content) ->
      if err?
        robot.emit 'error', err, msg
        return
      robot.messageRoom incidentRoom, formatMarkDown(content)

    #delete robot.brain.data.incidents[incidentNumber]

  # Store timestamps in epoch (milliseconds from epoch)
  # Store durations in seconds
  # This makes the maths easier later
  # Use moment functions for display
  buildIncidentHash: (incidentNumber) ->
    incidentHash = {}
    # bot known times
    incidentHash['start_time'] = this.getCurrentTime()
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

  updateTimestamp: (incidentNumber, type, timestamp, robot) ->
    if robot.brain.data.incidents[incidentNumber]
      incidentHash = robot.brain.data.incidents[incidentNumber]
      incidentHash['type'] = timestamp
    else 
      log_message = "Issue setting timestamp for #{type} on incident #{incidentNumber} into hubot brain"
      console.log log_message
      robot.messageRoom incidentRoom, log_message

  formatMarkDown: (content) ->
    block = "```\n"
    block += content
    block += "```\n"
    block

  ##### Pager Duty interaction
  getPagerDutyServiceUser: (msg, required, robot, cb) ->
    if typeof required is 'function'
      cb = required
      required = true
    pagerduty.get "/users/#{pagerDutyUserId}", (err, json) ->
      if err?
        robot.emit 'error', err, msg
        return

      if json.user.id != pagerDutyUserId
        robot.messageRoom incidentRoom, "Sorry, I expected to get 1 user back for #{pagerDutyUserId}, but got #{json.user.id} :sweat:. If the bot user for PagerDuty's ID is not #{pdServiceEmail} please reconfigure"
        return

      cb(json.user)

  postNoteToPagerDuty: (msg, incidentNumber, note, robot) ->
    if pagerduty.missingEnvironmentForApi(msg)
      #TODO: error handling
      robot.messageRoom incidentRoom, "PagerDuty setup needs work."
    else
      this.getPagerDutyServiceUser msg, (user) ->
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
          #  robot.messageRoom incidentRoom, "Transcript of room added to Pagerduty note since #{incidentHash['start_time']}"
          #else
          #  robot.messageRoom incidentRoom, "Sorry, could not add transcript of room to PagerDuty as note."

  checkIfIncidentOpen: (msg, incidentNumbers, statusFilter, robot, cb) ->
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
        robot.messageRoom incidentRoom, "Couldn't find incident(s) #{incidentNumbers}. Use `#{robot.name} pager incidents` for listing. \n Tracking can only be started on unresolved incidents."
        cb null
        return
      else
        cb true
        return

  ##### Moment calculations
  calculateDuration: (start, end) ->
    Math.floor(moment.duration(moment(end,"YYYYMMDDTHHmmss").diff(moment(start,"YYYYMMDDTHHmmss"))).asHours())+moment.utc(moment(end,"YYYYMMDDTHHmmss").diff(moment(start,"YYYYMMDDTHHmmss"))).format(":mm:ss")
  
  getCurrentTime: () ->
    now = moment()
    time = now.format('YYYY-MM-DD HH:mm:ss Z')
