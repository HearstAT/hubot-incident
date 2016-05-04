# hubot-incident
[![NPM version][npm-image]][npm-url] [![Build Status][travis-image]][travis-url] [![Coverage Status][coveralls-image]][coveralls-url]

Incident coordination for [Hubot](https://hubot.github.com)

**NOTE:**This is a work in progress to track an incident through the process.

## Installation

In your hubot repository, run:

`npm install hubot-incident --save`

Then add **hubot-incident** to your `external-scripts.json`:

```json
["hubot-incident"]
```

## Configuration

* `HUBOT_INCIDENT_START_CHECKLIST_URL` - optional, defaults to this project in github (deprecated will move to dynamic list)
* `HUBOT_INCIDENT_END_CHECKLIST_URL` - optional, defaults to this project in github (deprecated will move to dynamic list)
* `HUBOT_INCIDENT_PAGERDUTY_ROOM` - room that the webhooks should go to
* `HUBOT_INCIDENT_PAGERDUTY_ENDPOINT` - for webhooks to listen default to '/incident' Set it to whatever URL you want, and make sure it is different than your pagerduty service settings

From [hubot-pager-me](https://github.com/hubot-scripts/hubot-pager-me) config

* `HUBOT_PAGERDUTY_SUBDOMAIN`
* `HUBOT_PAGERDUTY_USER_ID`
* `HUBOT_PAGERDUTY_TEST_EMAIL` - optional for testing

## Interaction/Process

## Development

## Resources
* [hubot-pager-me](https://github.com/hubot-scripts/hubot-piager-me)

[npm-url]: https://www.npmjs.org/package/hubot-incident
[npm-image]: http://img.shields.io/npm/v/hubot-incident.svg?style=flat
[travis-url]: https://travis-ci.org/HearstAT/hubot-incident
[travis-image]: https://travis-ci.org/HearstAT/hubot-incident.svg?branch=master
[coveralls-url]: https://coveralls.io/r/HearstAT/hubot-incident
[coveralls-image]: http://img.shields.io/coveralls/HearstAT/hubot-incident/master.svg?style=flat
