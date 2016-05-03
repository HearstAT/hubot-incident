# Description:
#  Orderly incident coordination through hubot
#
# Dependencies:
#   "moment": "latest"
#
# Configuration:
#   HUBOT_INCIDENT_PAGERDUTY_ROOM - room that the webhooks should go to
#   HUBOT_INCIDENT_PAGERDUTY_ENDPOINT - for webhooks to listen default to '/incident' Set it to whatever URL you want, and make sure it is different than your pagerduty service settings
#   HUBOT_INCIDENT_START_CHECKLIST_URL - optional (deprecated will move to dynamic list)
#   HUBOT_INCIDENT_END_CHECKLIST_URL - optional (deprecated will move to dynamic list)
#
#   #From hubot-pager-me config
#   HUBOT_PAGERDUTY_TEST_EMAIL
#   HUBOT_PAGERDUTY_SUBDOMAIN
#   HUBOT_PAGERDUTY_USER_ID
#   
# Commands:
#   hubot incident track <pagerduty id> - Manually initiate incident
#   hubot incident resolve <pagerduty id> - Manually resolve incident
#   hubot incident show (open|resolved|closed) - List out the incidents currently being tracked in the hubot brain by status
#
# Authors:
#   Aaron Blythe
#   Levi Smith

# Dependencies
moment = require('moment')
checklists = require('../documentation/checklist_md')
pagerduty = require('../pagerduty/pagerduty')
incident_shared = require('../incident')

# Envrionment Variables
incidentRoom     = process.env.HUBOT_INCIDENT_PAGERDUTY_ROOM
incidentEndpoint = process.env.HUBOT_INCIDENT_PAGERDUTY_ENDPOINT || "/incident"
pagerDutyUserId  = process.env.HUBOT_PAGERDUTY_USER_ID


module.exports = (robot) ->
  unless robot.brain.data.incidents?
    robot.brain.data.incidents = {}

  robot.respond /incident track (\d+)/i, (msg) ->
    # TODO: work on auth so only the specified users are responded to
    incidentNumber = msg.match[1]
    incident_shared.trackIncident(incidentNumber, msg, robot)

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
    if status == "resolved"
      tracking = "Resolved in PagerDuty: \n"
    else if status == "closed"
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
    incident_shared.resolveIncident(incidentNumber, msg, robot)
  
  robot.respond /incident help/i, (msg) ->
    commands = robot.helpCommands()
    commands = (command for command in commands when command.match(/incident/))
    msg.send commands.join("\n")

  ## TODO: ensure only get the messages from the incident room
  robot.hear /(.+)/, (msg) ->
    for k,v of robot.brain.data.incidents
      if robot.brain.data.incidents[k]['status'] == "open"
        note = "#{incident_shared.getCurrentTime()}  #{msg.message.user.name} #{msg.message.text} \n"
        robot.brain.data.incidents[k]['log'] += note
        incident_shared.postNoteToPagerDuty(msg,k,note,robot)
