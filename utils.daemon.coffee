conf =
	test: no
	allow_restart: yes
	log_to_console: yes
	killAfter: no
	killSignal: 'SIGKILL'
	log_filename: 'main'
	non_restartable_codes: [130, 143]
	libs: ['fs', 'child_process','q']
	encoding: 'utf8'
	port: 8124
	host: '127.0.0.1'
	paths:
		log: 'logs/'

# Required libraries
utils = require './utils/utils' 
[fs, cp, Q] = utils.requireAll conf.libs

FS = module.exports = exports = {}

FS.processes = {}
FS.workers = {}
	# http_server: {cmd: 'coffee', file:'./run/http_server.run.coffee', options:{restart:yes, concurrent:1, test:conf.test}}

FS._date = (-> new Date())()
FS._timestamp = (-> FS._date.getTime())()

FS.ensurePath = (path) ->
	if (path = path or "./" and path.substr -1 isnt "/") then path = "#{path}/"; path

FS.filename = (name, proc) ->
	"#{name}.#{@_timestamp}.#{proc.pid}"

FS.log = (text, filename=conf.log_filename, toConsole=yes, showMain=yes, log_path=conf?.paths?.log or "logs/") ->
	ret = no; ignore = ["", "^"]
	(ret = yes if ignore is i ) for i in ignore
	if ret then return false

	#text = text.trim()
	showMain = if showMain then "['Main'] " else ""
	utils.ensureFolderExists @ensurePath log_path

	console.log "#{showMain}#{text}" if toConsole and conf.log_to_console
	fs.appendFile "#{log_path}#{filename or @_timestamp}.log", "#{text}\n", (err) ->
		console.log err if err and conf.log_to_console

FS.stopOnError = (error) ->
	ret = no; errors = ["EADDRINUSE", "getaddrinfo", "ENOTFOUND"]
	(ret = yes if error.indexOf(e) isnt -1) for e in errors; ret

FS.spawn = (name, worker, options=worker.options) ->
	opt = ["#{worker.file}"]
	opt.push JSON.stringify options if options
	proc = cp.spawn "#{worker.cmd}", opt, {stdio: ['ipc']}
	filename = @filename name, proc

	@log "#{name.ucfirst()} Launched...", conf.log_filename
	@log "#{name.ucfirst()} Launched on #{@_date}...", filename, no

	proc.stdout.on 'data', (data) =>
		if @stopOnError(data.toString conf.encoding) then options.restart = no
		@log data.toString(conf.encoding), filename, yes, no

	proc.on 'message', (message) =>
		@log message, filename

	proc.stderr.on 'data', (data) =>
		if @stopOnError(data.toString conf.encoding) then options.restart = no
		@log data.toString(conf.encoding), filename

	proc.on 'uncaughtException', (err) =>
		@log "#{name.ucfirst()}:#{proc.pid} had an Uncaught Exception: #{err}", filename
		@kill proc.pid	

	proc.on 'exit', (code, signal) =>
		delete @processes[proc.pid]
		@log "#{name.ucfirst()}:#{proc.pid} exited with code #{code} @ #{new Date()}", filename if code
		@log "#{name.ucfirst()}:#{proc.pid} killed with signal #{signal} @ #{new Date()}", filename if signal
		@run name if options?.restart and conf.allow_restart is yes and signal isnt conf.killSignal and conf.non_restartable_codes.indexOf(code) is -1 

FS.setup_master = () ->
	proc = process
	filename = conf.log_filename

	@log "Master Launched on #{@_date}...", filename

	proc.stdout.on 'data', (data) =>
		@log data.toString(conf.encoding), filename

	proc.on 'message', (message) =>
		@log message, filename

	proc.stderr.on 'data', (data) =>
		@log data.toString(conf.encoding), filename

	proc.on 'uncaughtException', (err) =>
		@log "Master:#{proc.pid} had an Uncaught Exception: #{err}", filename
		proc.kill conf.killSignal

	proc.on 'SIGINT', =>
		conf.allow_restart = no
		@log "Main killed with signal SIGINT @ #{new Date()}", filename
		@kill() if (utils.length @processes)

	proc.on 'SIGTERM', =>
		conf.allow_restart = no
		@log "Main killed with signal SIGTERM @ #{new Date()}", filename
		@kill() if (utils.length @processes)

	proc.on 'exit', (code) =>
		conf.allow_restart = no
		@log "Main exited with code #{code} @ #{new Date()}", filename
		@kill() if (utils.length @processes)

FS.kill = (pid, signal=conf.killSignal) ->
	if pid and @processes[pid] 
		@processes[pid].kill signal
		delete @processes[pid]
	else arguments.callee.call @, pid, signal for pid, worker of @processes


FS.run = (name, killAfter=conf.killAfter, sm=false) ->
	@setup_master() if sm
	setTimeout @kill, killAfter if killAfter
	if name and @workers[name]
		proc = @spawn name, @workers[name]
		return @processes[proc.pid] = proc

	for name, worker of @workers
		c = (utils.isInt worker.options?.concurrent) or 1	
		arguments.callee.call @, name for i in [1..c] by 1

	@log "#{utils.length @processes} Processes Launched on #{@_date}", conf.log_filename

(-> FS.run(null, null, true))()