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
#   hubot incident start - Initiate incident
#   hubot incident end - Resolve incident
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
HubotSlack = require 'hubot-slack'

module.exports = (robot) ->
  #if robot.brain.data.openincidents == null
  robot.brain.data.openincidents = {}

  # This is invoked by the Slack/Hubot integration here:
  # * https://slack.com/apps/A0F81FMQW-pagerduty
  # * https://www.pagerduty.com/docs/guides/slack-integration-guide/
  #robot.hear /Triggered: Incident #(\d+) \(([A-Z0-9]+)\)/, (msg) ->
  triggeredRegex = /Triggered: Incident/
  # NOTE when using the Slack listenter only get "Triggered: Incident" and not the ID
  # commented on https://github.com/slackhq/hubot-slack/issues/245
  robot.listeners.push new HubotSlack.SlackBotListener robot, triggeredRegex, (msg) ->
    logMessageContents (msg)
    # TODO: work on auth so only the PagerDuty bot is responded to
    incidentNumber = msg.match[1]
    incidentHash = buildIncidentHash(incidentNumber,msg.match[2])
    console.log "INCIDENT NOTIFY: Incident #{incidentNumber} has been started"
    msg.emote "Bot has started logging all conversation in this room as of #{incidentHash['start_time']}"
    checklists.getChecklist 'start', (err, content) ->
      if err?
        robot.emit 'error', err, msg
        return
      msg.send formatMarkDown(content)

  # helper function to show this works, should be removed when debugging is done
  robot.respond /incident log (\d+)/i, (msg) ->
    incidentHash = robot.brain.data.openincidents[msg.match[1]]
    msg.send incidentHash['log']

  #robot.hear /Resolved: Incident #(\d+) \(([A-Z0-9]+)\)/, (msg) ->
  resolvedRegex = /Resolved: Incident/
  # NOTE when using the Slack listenter only get "Resolved: Incident" and not the ID
  # commented on https://github.com/slackhq/hubot-slack/issues/245
  robot.listeners.push new HubotSlack.SlackBotListener robot, resolvedRegex, (msg) ->
    logMessageContents (msg)
    # TODO: work on auth so only the PagerDuty bot is responded to
    incidentNumber = msg.match[1]
    incidentHash = robot.brain.data.openincidents[incidentNumber]
    incidentHash['end_time'] = getCurrentTime()
    duration = calculateDuration(incidentHash['start_time'],incidentHash['end_time'])
    postNoteToPagerDuty(msg, incidentNumber, incidentHash)
    msg.send "INCIDENT NOTIFY: Resolved incident #{incidentNumber}, Incident duration: "
    checklists.getChecklist 'end', (err, content) ->
      if err?
        robot.emit 'error', err, msg
        return
      msg.send formatMarkDown(content)

    delete robot.brain.data.openincidents[incidentNumber]
  
  robot.respond /incident help/i, (msg) ->
    commands = robot.helpCommands()
    commands = (command for command in commands when command.match(/incident/))
    msg.send commands.join("\n")

  robot.hear /(.+)/, (msg) ->
    #logMessageContents (msg)
    for k,v of robot.brain.data.openincidents
      note = "#{getCurrentTime()}  #{msg.message.user.name} #{msg.message.text} \n"
      robot.brain.data.openincidents[k]['log'] += note
      postNoteToPagerDuty(msg,k,note)

  buildIncidentHash = (incidentNumber, urlId) ->
    debugger
    robot.brain.data.openincidents[incidentNumber] = {}
    incidentHash = robot.brain.data.openincidents[incidentNumber]
    incidentHash['start_time'] = getCurrentTime()
    incidentHash['end_time'] = ""
    incidentHash['url'] = urlId
    incidentHash['log'] = ""
    incidentHash

  formatMarkDown = (content) ->
    block = "```\n"
    block += content
    block += "```\n"
    block

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

  calculateDuration = (start, end) ->
    Math.floor(moment.duration(moment(end,"YYYYMMDDTHHmmss").diff(moment(start,"YYYYMMDDTHHmmss"))).asHours())+moment.utc(moment(end,"YYYYMMDDTHHmmss").diff(moment(start,"YYYYMMDDTHHmmss"))).format(":mm:ss")
  
  getCurrentTime = () ->
    now = moment()
    time = now.format('YYYY-MM-DD HH:mm:ss Z')

  logMessageContents = (msg) ->
    @robot.logger.info "**** Message:\n"
    @robot.logger.info "User: #{msg.message.user.name} ID: #{msg.message.user.id} Room: #{msg.message.user.room} \n"
    @robot.logger.debug "Type: #{msg.message.constructor.name} \n"
    @robot.logger.debug "msg.message.id: #{msg.message.id} \n"
    @robot.logger.debug "msg.message.room: #{msg.message.room} \n"
    @robot.logger.debug "msg.message.text: #{msg.message.text} \n"
    @robot.logger.debug "msg.match.length: #{msg.match.length} \n"
    @robot.logger.debug "msg.match[0]: #{msg.match[0]} \n"
    @robot.logger.debug "msg.match[1]: #{msg.match[1]} \n"
    @robot.logger.debug "msg.match.input: #{msg.match.input} \n"
    
