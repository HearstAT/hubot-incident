# hubot-incident
[![NPM version][npm-image]][npm-url]
[![Build Status][travis-image]][travis-url]
[![Coverage Status][coveralls-image]][coveralls-url]

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
We're mimicking the [hubot-pager-me](https://github.com/hubot-scripts/hubot-pager-me) configuration so both can be utilized together.

* HUBOT_PAGERDUTY_SUBDOMAIN - Your account subdomain
* HUBOT_PAGERDUTY_USER_ID - The user id of a PagerDuty user for your bot. This is only required if you want chat users to be able to trigger incidents without their own PagerDuty user
* HUBOT_PAGERDUTY_API_KEY - Get one from https://<your subdomain>.pagerduty.com/api_keys
* HUBOT_PAGERDUTY_SERVICE_API_KEY - Service API Key from a 'General API Service'. This should be assigned to a dummy escalation policy that doesn't actually notify, as hubot will trigger on this before reassigning it

## Interaction/Process

## Development

## Resources
* [hubot-pager-me](https://github.com/hubot-scripts/hubot-pager-me)

[npm-url]: https://www.npmjs.org/package/hubot-incident
[npm-image]: http://img.shields.io/npm/v/hubot-incident.svg?style=flat
[travis-url]: https://travis-ci.org/TheFynx/hubot-incident
[travis-image]: https://travis-ci.org/TheFynx/hubot-incident.svg?branch=master
[coveralls-url]: https://coveralls.io/r/hearstat/hubot-incident
[coveralls-image]: http://img.shields.io/coveralls/hearstat/hubot-incident/master.svg?style=flat
