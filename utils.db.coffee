
conf =
	libs: ['mysql', 'q', 'mime']
	encoding: 'utf8'
	port: 8124
	host: '127.0.0.1'
	verbose: yes
	debug: no


utils = require './utils'
[mysql, Q, mime] = utils.requireAll conf.libs

_db = module.exports = exports = {}

_db.settings =
	public: yes
	db_config: 
	close_connection: false
	paths:
		config: "./config/config.api_broker.json"

_db.conn = false
_db.setup = (options, config) ->
	settings = utils.extend @settings, options

	if config then @settings.db_config = config
	else @settings.db_config = utils.readFile @settings.paths.config, true

	@conn = mysql.createConnection @settings.db_config

_db.close = (conn = @conn) ->
	conn.end()

_db.parameterize = (obj) ->
	unless utils.isObject obj then return obj
	len = utils.length obj
	str = ''; i = 1

	for x, y of obj
		str+= "#{x} = #{y}"
		str+= " AND " if i < len 
		i++

_db.queryBuilder = () ->
	args = arguments; query = ''
	return query unless args.length

	cases =
		select: (args) ->
			query+= "SELECT" if args[0]
			query+= "#{args[1]}" if args[1]	
			query+= "FROM #{args[2]}" if args[2]
			query+= "WHERE #{_db.parameterize args[3]}" if args[3]
			query
		insert: (args) ->
			query+= "INSERT INTO" if args[0]
			query+= "#{args[1]}" if args[1]	
			query+= "VALUES (#{args[2].toString()})" if args[2]
			query
		update: (args) ->
			query+= "UPDATE" if args[0]
			query+= "#{args[1]}" if args[1]	
			query+= "SET #{args[2].toString()}" if args[2]
			query+= "WHERE #{_db.parameterize args[3]}" if args[3]
			query
		delete: (args) ->
			query+= "DELETE" if args[0]
			query+= "#{args[1]}" if args[1]	
			query+= "FROM #{args[2]}" if args[2]
			query+= "WHERE #{_db.parameterize args[3]}" if args[3]
			query


	if cases[args[0]?.toLowerCase()]
		query = cases[args[0].toLowerCase()].call(this, args)
	query

_db.query = (query, conn=@conn, close = @close_connection) ->
	task = Q.defer()
	conn.query query, (err, rows, fields) =>
		if err then return task.reject err
		return task.resolve rows
	@close conn if close
	task.promise

_db.select = (s, f, w, conn=@conn, close = @close_connection) ->
	query = @queryBuilder 'select', s, f, w
	@query query, conn, close

_db.insert = (s, f, w, conn=@conn, close = @close_connection) ->
	query = @queryBuilder 'insert', s, f, w
	@query query, conn, close

_db.update = (s, f, w, conn=@conn, close = @close_connection) ->
	query = @queryBuilder 'update', s, f, w
	@query query, conn, close

_db.delete = (s, f, w, conn=@conn, close = @close_connection) ->
	query = @queryBuilder 'delete', s, f, w
	@query query, conn, close
