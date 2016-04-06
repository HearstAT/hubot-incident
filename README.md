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

* `HUBOT_INCIDENT_START_CHECKLIST_URL` - URL to a checklist for the start of an incident in markdown (will default to checklist in this project)
* `HUBOT_INCIDENT_END_CHECKLIST_URL` - URL to a checklist for the start of an incident in markdown (will default to checklist in this project)

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
