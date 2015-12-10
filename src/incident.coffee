# Description:
# #  OPrderly incident coordination through hubot
# #
# # Dependencies:
# #   "<module name>": "<module version>"
# #
# # Configuration:
# #   HUBOT_GITHUB_TOKEN (required)
# #   HUBOT_GITHUB_ORG (required)
# #
# # Commands:
# #   hubot incident start - Initiate incident
# #   hubot incident ack - Aknowledge started incident
# #   hubot incident end - Resolve incident
# #
# # Notes:
# #   <optional notes required for the script>
# #
# # Authors:
# #   Aaron Blythe
# #   Levi Smith


#GitHubApi = require "github"

module.exports = (robot) ->
#  ghToken       = process.env.HUBOT_GITHUB_TOKEN
#  ghOrg         = process.env.HUBOT_GITHUB_ORG

  robot.respond /incident (start|initiate)/i, (msg) ->
    # Probably set to the brain via the notify portion of the bot in non-hacky version
    robot.brain.set 'incidentNumber', @_randomNum(10,5)
    robot.brain.get('incidentNumber')
    msg.reply "INCIDENT NOTIFY: Incident #{incidentNumber} has been started"

  robot.respond /incident (ack|acknowledge)/i, (msg) ->
    robot.brain.get('incidentNumber')
    msg.reply "INCIDENT NOTIFY: Acknowledged incident #{incidentNumber}"

  robot.respond /incident (end|resolve)/i, (msg) ->
    robot.brain.get('incidentNumber')
    msg.reply "INCIDENT NOTIFY: Resolved incident #{incidentNumber}"

