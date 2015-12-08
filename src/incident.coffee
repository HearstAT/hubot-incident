# Description:
#   Orderly incident coordination through hubot
#
# Configuration:
#   HUBOT_GITHUB_TOKEN (required)
#   HUBOT_GITHUB_ORG (required)
#
# Commands:
#   hubot incident start - Mark this time as the start of the incident
#   hubot incident ack - Mark this time as incident acknowledged
#   hubot incident resolve - Mark this time as incident resolved
# Author:
#   aaronblythe

GitHubApi = require "github"

module.exports = (robot) ->
  ghToken       = process.env.HUBOT_GITHUB_TOKEN
  ghOrg         = process.env.HUBOT_GITHUB_ORG

  robot.respond /incident start/i, (msg) ->
    msg.reply "Incident has started!"

  robot.respond /incident ack/i, (msg) ->
    msg.reply "Incident has been acknowledged."

  robot.respond /incident resolve/i, (msg) ->
    msg.reply "Incident has been resolved!"

