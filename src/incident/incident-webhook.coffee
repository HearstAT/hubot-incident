
incidentRoom       = process.env.HUBOT_INCIDENT_PAGERDUTY_ROOM
incidentEndpoint   = process.env.HUBOT_INCIDENT_PAGERDUTY_ENDPOINT || "/incident"

incident_file = require('../incident')

module.exports = (robot) ->
  if incidentEndpoint && incidentRoom
    console.log "Webhooks should be configured properly.\n Incident Room: #{incidentRoom} \n Incident Endpoint: #{incidentEndpoint}"
    robot.router.post incidentEndpoint, (req, res) ->
      # TODO: untangle this some so that when there is nothing to post do not get odd call stack in the log
      # `TypeError: msg.replace is not a function`
      # http://stackoverflow.com/questions/4775206/var-replace-is-not-a-function
      #robot.messageRoom(incidentRoom, parseWebhook(req,res))
      parseWebhook(req,res)
      res.end()
  else
    endpoint_log = "HUBOT_INCIDENT_PAGERDUTY_ENDPOINT is set to #{incidentEndpoint} \n"
    room_log = "HUBOT_INCIDENT_PAGERDUTY_ROOM is set to #{incidentRoom}\n"
    console.log "Either HUBOT_INCIDENT_PAGERDUTY_ROOM or HUBOT_INCIDENT_PAGERDUTY_ENDPOINT is not set \n #{endpoint_log} \n #{room_log}\n Please set these environment variables\n"

  # Pagerduty Webhook Integration (For a payload example, see http://developer.pagerduty.com/documentation/rest/webhooks)
  parseWebhook = (req, res) ->
    hook = req.body

    messages = hook.messages

    if /^incident.*$/.test(messages[0].type)
      parseIncidents(messages)
    else
      "No incidents in webhook"

  parseIncidents = (messages) ->
    for message in messages
      incident = message.data.incident
      hookType = message.type
      updateIncidentBot(incident, hookType, message)

  getUserForIncident = (incident) ->
    if incident.assigned_to_user
      incident.assigned_to_user.email
    else if incident.resolved_by_user
      incident.resolved_by_user.email
    else
      '(???)'

  updateIncidentBot = (incident, hookType, message) ->
    console.log "hookType is " + hookType
    assigned_user   = getUserForIncident(incident)
    incident_number = incident.incident_number
    timestamp = message.data.incident.last_status_change_on

    if hookType == "incident.trigger"
      incident_file.updateTimestamp(incident_number,"pd_trigger_time",timestamp, robot)
      incident_file.trackIncident(incident_number, null, robot)
    else if hookType == "incident.acknowledge"
      incident_file.updateTimestamp(incident_number,"pd_ack_time",timestamp, robot)
    else if hookType == "incident.resolve"
      incident_file.updateTimestamp(incident_number,"pd_resolve_time",timestamp, robot)
      incident_file.resolveIncident(incident_number, null, robot)
    else if hookType == "incident.unacknowledge"
      incident_file.updateTimestamp(incident_number,"pd_unacknowledge_time",timestamp, robot)
    else if hookType == "incident.assign"
      incident_file.updateTimestamp(incident_number,"pd_assign_time",timestamp, robot)
    else if hookType == "incident.escalate"
      incident_file.updateTimestamp(incident_number,"pd_escalate_time",timestamp, robot)
