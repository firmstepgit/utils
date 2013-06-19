conf =
	libs: ['q', 'validator']
	encoding: 'utf8'
	port: 8124
	host: '127.0.0.1'
	verbose: yes
	debug: no

utils = require './utils'
datejs = require '../libs/date.js'

[Q, validator] = utils.requireAll conf.libs

_validator = module.exports = exports = {}

_validator.settings =
	formats: 
    	date: 'yyyy-MM-dd'
    	time: 'HH:mm:ss'
    	datetime: 'yyyy-MM-dd HH:mm:ss'
	paths:
		config: "../config/config.api_broker.json"
		aws: "../config/config.aws.json"

( ->
	fn = 
		maxdate: (str) ->
	    	format = _validator.settings.formats.date

	    	if Date.parseExact(@str, format) and Date.parse str
	    		val = Date.parseExact(@str, format).compareTo(Date.parse(str)) <= 0
	    		unless val then @error @msg or 'Value is greater than max allowed'
	    	else @error @msg or 'Not a valid Date value'
	    	return @

		mindate: (str) ->
	    	format = _validator.settings.formats.date

	    	if Date.parseExact(@str, format) and Date.parse str
	    		val = Date.parseExact(@str, format).compareTo(Date.parse(str)) >= 0
	    		unless val then @error @msg or 'Value is greater than max allowed'
	    	else @error @msg or 'Not a valid Date value'
	    	return @

		maxdatetime: (str) ->
	    	format = _validator.settings.formats.datetime

	    	if Date.parseExact(@str, format) and Date.parse str
	    		val = Date.parseExact(@str, format).compareTo(Date.parse(str)) <= 0
	    		unless val then @error @msg or 'Value is greater than max allowed'
	    	else @error @msg or 'Not a valid Datetime value'
	    	return @

		mindatetime: (str) ->
	    	format = _validator.settings.formats.datetime

	    	if Date.parseExact(@str, format) and Date.parse str
	    		val = Date.parseExact(@str, format).compareTo(Date.parse(str)) >= 0
	    		unless val then @error @msg or 'Value is greater than max allowed'
	    	else @error @msg or 'Not a valid Datetime value'
	    	return @


		maxtime: (str) ->
	    	format = _validator.settings.formats.time

	    	if Date.parse(@str) and Date.parse str
	    		val = Date.parse(@str).compareTo(Date.parse(str)) <= 0
	    		unless val then @error @msg or 'Value is less than minimum allowed'
	    	else @error @msg or 'Not a valid Time value'
	    	return @

		mintime: (str) ->
	    	format = _validator.settings.formats.time

	    	if Date.parse(@str) and Date.parse str
	    		val = Date.parse(@str).compareTo(Date.parse(str)) >= 0
	    		unless val then @error @msg or 'Value is less than minimum allowed'
	    	else @error @msg or 'Not a valid Time value'
	    	return @

		isDate: () ->
	    	format = _validator.settings.formats.date

	    	unless Date.parseExact(@str, format) then @error @msg or 'Not a valid Time value'
	    	return @

		isTime: () ->
	    	format = _validator.settings.formats.time

	    	unless Date.parse(@str) then @error @msg or 'Not a valid Time value'
	    	return @

	    isDatetime: () ->
	    	format = _validator.settings.formats.datetime

	    	unless Date.parseExact(@str, format) then @error @msg or 'Not a valid Date Time value'
	    	return @

	utils.extend validator.Validator.prototype, fn

)()

_validator.error = (err) ->
	{error: err}

_validator.validateType = (value, field, type) ->

	fn =
		text: -> true
		textarea: -> true
		hidden: -> true
		secret: -> true
		select: -> true
		checkbox: -> true
		radio: -> true
		lookupSelect: -> true
		upload: -> true
		subform: -> true
		number: (v, f) -> 
			validator.check(v).isFloat()
		date: (v, f) ->
			validator.check(v).isDate()
		time: (v, f) ->
			validator.check(v).isTime()
		datetime: (v, f) ->
			validator.check(v).isDatetime()
		map: (v, f) -> 
			utils.isArray(v) and v.length is 2 and validator.check(v[0]).isFloat() and validator.check(v[1]).isFloat()
		range: (v, f) -> 
			validator.check(v).isFloat()
	try 
		return fn[type](value, field)
	catch e 
		return false

_validator.checkField = (value, field, type) ->
	err
	# Props validation
	# console.log "['Validator']", "Field Props", field.props
	for x, y of field.props
		if utils.isEmpty y then continue
		try
			if x is "validationMask"
				validator.check(value).regex(utils.textToRegex field.props.validationMask)

			if x is "decimalPlaces"
				validator.check(value).regex(new RegExp "^[0-9]+(\\.\\d{"+field.props.decimalPlaces+"})$")

			if x is "maximumLength" or x is "minimumLength"
				validator.check(value).len(field.props.minimumLength or 0, field.props.maximumLength or null)

			if x is "maximumValue"
				unless type is 'date' or type is 'time' or type is 'datetime'
					validator.check(validator.sanitize(value).toFloat()).max(field.props.maximumValue)
				else if type is 'date'
					validator.check(value).maxdate(field.props.maximumValue)
				else if type is 'time'
					validator.check(value).maxtime(field.props.maximumValue)
				else if type is 'datetime'
					validator.check(value).maxdatetime(field.props.maximumValue)

			if x is "minimumValue"
				unless type is 'date' or type is 'time' or type is 'datetime'
					validator.check(validator.sanitize(value).toFloat()).min(field.props.minimumValue)
				else if type is 'date'
					validator.check(value).mindate(field.props.minimumValue)
				else if type is 'time'
					validator.check(value).mintime(field.props.minimumValue)
				else if type is 'datetime'
					validator.check(value).mindatetime(field.props.minimumValue)
			
		catch e
			err = {value: value, error_on: [x, y], message: e.message}; break;

	# Mandatory Validation
	unless field.props.optional or err
		try
			validator.check(value).notEmpty()
		catch e
			err = {value: value, error_on: ['optional', true], message: e.message}

	# Field Type Validation
	unless utils.isEmpty value or err
		a = _validator.validateType value, field, type
		msg = "This field's value does not match the allowed values for this field type"
		err = {value: value, error_on: ['Field Type', type], message: msg} if a is false

	return _validator.error utils.isJSON(err, true) if err
	return true
