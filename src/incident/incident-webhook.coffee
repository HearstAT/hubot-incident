
incidentRoom       = process.env.HUBOT_INCIDENT_PAGERDUTY_ROOM
incidentEndpoint   = process.env.HUBOT_INCIDENT_PAGERDUTY_ENDPOINT || "/incident"

incident = require('../incident')

module.exports = (robot) ->
  if incidentEndpoint && incidentRoom
    robot.router.post incidentEndpoint, (req, res) ->
      robot.messageRoom(incidentRoom, parseWebhook(req,res))
      res.end()

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

  generateIncidentString = (incident, hookType, message) ->
    console.log "hookType is " + hookType
    assigned_user   = getUserForIncident(incident)
    incident_number = incident.incident_number
    timeStamp = message.data.incident.last_status_change_on

    if hookType == "incident.trigger"
      incident.updateTimestamp(incident_number,pd_trigger_time,timestamp)
      incident.trackIncident(incident_number, null)
    else if hookType == "incident.acknowledge"
      incident.updateTimestamp(incident_number,pd_ack_time,timestamp)
    else if hookType == "incident.resolve"
      incident.updateTimestamp(incident_number,pd_resolve_time,timestamp)
      incident.resolveIncident(incident_number, null)
    else if hookType == "incident.unacknowledge"
      incident.updateTimestamp(incident_number,pd_unacknowledge_time,timestamp)
    else if hookType == "incident.assign"
      incident.updateTimestamp(incident_number,pd_assign_time,timestamp)
    else if hookType == "incident.escalate"
      incident.updateTimestamp(incident_number,pd_escalate_time,timestamp)
