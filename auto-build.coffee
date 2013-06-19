
conf =
	logToConsole: no

githubhook = require 'githubhook'
{spawn} = require 'child_process'

servers = 
	'af-dev': 'https://github.com/firmstepgit/FS-R4'
refs =
	'af-dev': 'refs/heads/master'
	'af-staging': 'refs/heads/staging'

console.log 'Initialization....' if conf.logToConsole

githubhook 3000, servers, (err, payload) ->
	unless err
		console.log "[#{new Date().toLocaleString()}] Push notification recieved!" if conf.logToConsole
		dir = switch payload.ref
			when refs['af-dev'] then '/opt/firmstep/af-dev/'
			when refs['af-staging'] then '/opt/firmstep/af-staging/'

		from = "#{payload.ref.split(/\//g)[2]}"

		console.log "\nDirectory: #{dir}" if conf.logToConsole
		console.log "From Branch: #{from}\n" if conf.logToConsole

		process.chdir dir
		console.log "Pulling..." if conf.logToConsole
		pull = spawn 'git', ['pull', 'origin', from]
		pull.stderr.on 'data', (data) -> console.error data.toString() if conf.logToConsole
		pull.on 'exit', (code) ->
			console.log "Git pull returned #{code}" if conf.logToConsole
			if code is 0
				console.log "Building..." if conf.logToConsole
				cake = spawn 'cake', ['all']
				cake.stderr.on 'data', (data) -> console.error data.toString() if conf.logToConsole
				cake.on 'exit', (code) ->
					console.log "Cake returned #{code}" if conf.logToConsole
					console.log 'Done!' if conf.logToConsole and code is 0
	else
		console.log err if conf.logToConsole

console.log "Watching Servers:" if conf.logToConsole
console.log "\t#{v}" for k, v of servers if conf.logToConsole 

console.log 'Initialized and Running' if conf.logToConsole