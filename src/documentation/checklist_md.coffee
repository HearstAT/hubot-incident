HttpClient = require 'scoped-http-client'

StartChecklistURL = process.env.HUBOT_INCIDENT_START_CHECKLIST_URL or= 'https://raw.githubusercontent.com/HearstAT/hubot-incident/master/checklists/start.md'
EndChecklistURL = process.env.HUBOT_INCIDENT_END_CHECKLIST_URL or='https://raw.githubusercontent.com/HearstAT/hubot-incident/master/checklists/end.md'

module.exports =
  http: (path) ->
    HttpClient.create(path)

  get: (url, query, cb) ->
    if typeof(query) is 'function'
      cb = query
      query = {}
    @http(url)
      .query(query)
      .get() (err, res, body) ->
        if err?
          cb(err)
          return
        md_body = null
        switch res.statusCode
          when 200 then md_body = body
          else
            cb(new Error("#{res.statusCode} back from #{url}"))

        cb null, md_body

  getChecklist: (type, cb) ->
    url = switch type
      when 'start' then StartChecklistURL
      when 'end' then EndChecklistURL
    @get url, (err, json) ->
      if err?
        cb(err)
        return

      cb(null, json)
