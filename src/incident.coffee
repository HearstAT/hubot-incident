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

  if incidentEndpoint && incidentRoom
    robot.router.post incidentEndpoint, (req, res) ->
      robot.messageRoom(incidentRoom, parseWebhook(req,res))
      res.end()

  robot.respond /start (\d+)/i, (msg) ->
    # TODO: work on auth so only the specified users are responded to
    incidentNumber = msg.match[1]
    startIncident(incidentNumber, msg)

  # helper function to show this works, should be removed when debugging is done
  #robot.respond /incident log (\d+)/i, (msg) ->
  #  incidentHash = robot.brain.data.openincidents[msg.match[1]]
  #  msg.send incidentHash['log']

  robot.respond /incident currently tracking/i, (msg) ->
    for k,v of robot.brain.data.openincidents
      msg.emote "Currently tracking PagerDuty Incident #{k} from start time #{robot.brain.data.openincidents[k]['log']}"

  robot.respond /end (\d+)/i, (msg) ->
    # TODO: work on auth so only authorized users are responded to
    incidentNumber = msg.match[1]
    endIncident(incident_number, msg)
  
  robot.respond /incident help/i, (msg) ->
    commands = robot.helpCommands()
    commands = (command for command in commands when command.match(/incident/))
    msg.send commands.join("\n")

  ## TODO: ensure only get the messages from the incident room
  robot.hear /(.+)/, (msg) ->
    for k,v of robot.brain.data.openincidents
      robot.brain.data.openincidents[k]['log'] += "#{getCurrentTime()}  #{msg.message.user.name} #{msg.message.text} \n"

  ##### Functions

  # TODO: find a way to remove 'msg'
  startIncident = (incidentNumber, msg) ->
    #is inicident being tracked yet?
    for k,v of robot.brain.data.openincidents
      if k == incidentNumber
        mrobot.messageRoom(incidentRoom, "incident #{k} is already being tracked")
        return
    incidentHash = buildIncidentHash(incidentNumber)
    robot.brain.data.openincidents[incidentNumber] = incidentHash
    robot.messageRoom(incidentRoom, "INCIDENT NOTIFY: Incident #{incidentNumber} has been started")
    robot.messageRoom(incidentRoom, "Bot has started logging all conversation in this room as of #{robot.brain.data.openincidents[incidentNumber]['start_time']}")
    checklists.getChecklist 'start', (err, content) ->
      if err?
        robot.emit 'error', err, msg
        return
      msg.send formatMarkDown(content)

  # TODO: find a way to remove 'msg'
  endIncident = (incidentNumber, msg) ->
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

  postNoteToPagerDuty = (msg, incidentNumber, incidentHash) ->
    if pagerduty.missingEnvironmentForApi(msg)
      #TODO: error handling
      msg.send "PagerDuty setup needs work."
    else
      content = incidentHash['log']
      
      getPagerDutyServiceUser msg, (user) ->
        userId = user.id
        return unless userId

        data =
          note:
            content: incidentHash['log']
          requester_id: userId

        pagerduty.post "/incidents/#{incidentNumber}/notes", data, (err, json) ->
          if err?
            robot.emit 'error', err, msg
            return

          if json && json.note
            msg.send "Transcript of room added to Pagerduty note since #{incidentHash['start_time']}"
          else
            msg.send "Sorry, could not add transcript of room to PagerDuty as note."

  ##### PagerDuty Webhooks
  # Pagerduty Webhook Integration (For a payload example, see http://developer.pagerduty.com/documentation/rest/webhooks)
  parseWebhook = (req, res) ->
    hook = req.body

    messages = hook.messages

    if /^incident.*$/.test(messages[0].type)
      parseIncidents(messages)
    else
      "No incidents in webhook"

  parseIncidents = (messages) ->
    returnMessage = []
    count = 0
    for message in messages
      incident = message.data.incident
      hookType = message.type
      returnMessage.push(generateIncidentString(incident, hookType))
      count = count+1
    returnMessage.unshift("You have " + count + " PagerDuty update(s): \n")
    returnMessage.join("\n")

  getUserForIncident = (incident) ->
    if incident.assigned_to_user
      incident.assigned_to_user.email
    else if incident.resolved_by_user
      incident.resolved_by_user.email
    else
      '(???)'

  generateIncidentString = (incident, hookType) ->
    console.log "hookType is " + hookType
    assigned_user   = getUserForIncident(incident)
    incident_number = incident.incident_number

    if hookType == "incident.trigger"
      """
      Incident # #{incident_number} :
      #{incident.status} and assigned to #{assigned_user}
       #{incident.html_url}
      To acknowledge: @#{robot.name} pager me ack #{incident_number}
      To resolve: @#{robot.name} pager me resolve #{}
      """
      startIncident(incident_number, null)
    else if hookType == "incident.acknowledge"
      """
      Incident # #{incident_number} :
      #{incident.status} and assigned to #{assigned_user}
       #{incident.html_url}
      To resolve: @#{robot.name} pager me resolve #{incident_number}
      """
    else if hookType == "incident.resolve"
      """
      Incident # #{incident_number} has been resolved by #{assigned_user}
       #{incident.html_url}
      """
      endIncident(incident_number, null)
    else if hookType == "incident.unacknowledge"
      """
      #{incident.status} , unacknowledged and assigned to #{assigned_user}
       #{incident.html_url}
      To acknowledge: @#{robot.name} pager me ack #{incident_number}
       To resolve: @#{robot.name} pager me resolve #{incident_number}
      """
    else if hookType == "incident.assign"
      """
      Incident # #{incident_number} :
      #{incident.status} , reassigned to #{assigned_user}
       #{incident.html_url}
      To resolve: @#{robot.name} pager me resolve #{incident_number}
      """
    else if hookType == "incident.escalate"
      """
      Incident # #{incident_number} :
      #{incident.status} , was escalated and assigned to #{assigned_user}
       #{incident.html_url}
      To acknowledge: @#{robot.name} pager me ack #{incident_number}
      To resolve: @#{robot.name} pager me resolve #{incident_number}
      """

  ##### Moment calculations
  calculateDuration = (start, end) ->
    Math.floor(moment.duration(moment(end,"YYYYMMDDTHHmmss").diff(moment(start,"YYYYMMDDTHHmmss"))).asHours())+moment.utc(moment(end,"YYYYMMDDTHHmmss").diff(moment(start,"YYYYMMDDTHHmmss"))).format(":mm:ss")
  
  getCurrentTime = () ->
    now = moment()
    time = now.format('YYYY-MM-DD HH:mm:ss Z')
