
utils = require "utils"
((dust) ->
	dust.helpers = dust.helpers or {}

	helpers: 
		for: (chunk, context, bodies, params) ->
			params = params or {}
			for key of params
				a = dust.helpers.tap(params[key], chunk, context)
				params[key] = parseInt(a)

			from = params?.from
			to = params?.to
			limit = params?.limit 
			inc = params.inc? or (if to > from then 1 else -1)

			if from and to and not limit
				limit = (if inc > 0 then to - from else from - to)
			else if from and not to and limit
				to = (if inc > 0 then from + limit else from - limit)
			else if not from and to and limit
				from = (if inc > 0 then to - limit else to + limit)
			else if not from and to and limit
				from = 0
				to = limit
			else if not from and to and not limit
				from = 0
				limit = to
			if bodies.block
				first = true
				i = from

				while (if inc > 0 then i <= to else i >= to)
					localContext =
						i: i
						from: from
						to: to
						limit: limit
						inc: inc

				#need to add in local context to context
				if typeof context is "array"
					context.push localContext
				else context.localContext = localContext if typeof context is "object"

				chunk.render bodies.sep, context if not first and bodies.sep
				chunk.render bodies.block, context
				first = false
				i += inc
			chunk
		isMarkdown: (chunk, context, bodies, params) ->
			params = params or {}
			for key of params
				params[key] = dust.helpers.tap(params[key], chunk, context)

			testMarkdown = (value, close) ->
				value = value or ""
				return /^\[\/.+?\]$/.test(value)  if close
				/^\[[^\/].+?\]$/.test value

			if params.close and testMarkdown(params.value, true)
				chunk.render bodies.block, context
			else if testMarkdown(params.value)
				chunk.render bodies.block, context
			else chunk.render bodies["else"], context  if bodies["else"]
			chunk

	utils.extend dust.helpers, helpers
)(if typeof exports !== 'undefined' then module.exports = require('dustjs-linkedin') else dust)