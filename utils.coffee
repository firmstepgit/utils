
# You'd do well not to touch these options.
conf =
	libs: ['q', 'fs', 'child_process', 'dustjs-linkedin', 'dustjs-helpers', 'uglify-js', 'clean-css','less', 'watchr', 'crypto']
	encoding: 'utf8'
	port: 8124
	host: '127.0.0.1'
	verbose: no
	cipher:
		type: "AES-256-CBC"
		encoding: "base64"

utils = module.exports = exports = {}

utils.requireOne = (one) -> (utils.requireAll [one])[0]

utils.requireAll = (args) ->
	for module in args
		try
			require module
		catch e
			try 
				npm = require('child_process').spawn 'npm', ['install', module]
				npm.on 'exit', (code) ->
					utils.requireOne module
			catch e
				console.error "Could not load #{module} - please ensure that it has been installed via npm."
				process.exit 1


utils.require = -> utils.requireAll arguments

#Home Brewed Utils
require './utils.prototypes'

#Utils based on other libraries needs these moudles
[Q, fs, cp, dust, dusthelpers, uglify, clean_css, less, watchr, crypto] = utils.requireAll conf.libs

utils.inArray = (str, arr) ->
	return arr.indexOf(str) isnt -1

utils.fromBase64 = (str) ->
	b = (new Buffer(str or "", "base64")).toString conf.encoding or 'utf8'

utils.toBase64 = (str) ->
	b = (new Buffer(str or "", conf.encoding or 'utf8')).toString 'base64'

utils.isJSON = (str, isStr=false) ->
	if not str then return str
	try
		if isStr then fn = 'stringify' else fn = 'parse'		
		return JSON[fn] str
	catch e
		return false

utils.is = (obj) ->
	return obj if not obj
	Object.prototype.toString.call(obj).split(/\W/)[2].toLowerCase()

utils.isArray = (obj) ->
	utils.is(obj) is 'array'

utils.isObject = (obj) ->
	utils.is(obj) is 'object'

utils.isString = (obj) ->
	utils.is(obj) is 'string'

utils.isFunction = (obj) ->
	utils.is(obj) is 'function'

utils.isInt = (obj) ->
	if not isNaN parseInt obj then parseInt obj else false

utils.length = (obj) ->		
	switch
		when utils.isObject obj
			Object.keys(obj).length
		else obj.length

utils.extend = ->
	if arguments.length is 0 
		throw "extend function needs at least one argument"
	if arguments.length is 1 then return arguments[0]
	destination = arguments[0]

	addToDestination = (source, destination) ->
		for property of source
			if source[property] and source[property].constructor and source[property].constructor is Object
				destination[property] = destination[property] or {}
				utils.extend destination[property], source[property]
			else
				destination[property] = source[property]
	for s in arguments
		addToDestination s, destination
	destination

utils.uuid = ->
	'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
		r = Math.random() * 16 | 0
		v = if c is 'x' then r else (r & 0x3|0x8)
		v.toString(16)

utils.filterArray = (haystack, needle, reverse) ->
	haystack = haystack.filter(
		(item) ->
			out = true
			if typeof needle == 'string'
				if reverse and item.indexOf(needle) is -1
					out = false
				else if not reverse and item.indexOf(needle) isnt -1
					out = false
			else if typeof needle == 'object'
				for ndl in needle
					if reverse and item.indexOf(ndl) is -1
						out = false
					else if not reverse and item.indexOf(ndl) isnt -1
						out = false
			return out
	)
	
# Ensures that a folder exists
utils.ensureFolderExists = (folderPath, v) ->
	folders = folderPath.split /\//g

	if folderPath.charAt(0) is "/" 
		folders.shift()
		folders[0] = "/#{folders[0]}"

	incPath = []
	last = folders[folders.length - 1]

	if last.indexOf(".") isnt -1 then folders.pop()

	for name in folders
		if not name or name.trim() is '' then continue
		incPath.push name
		console.log "\tEnsuring Folder #{incPath.join '/'} exists..." if conf.verbose or v
		try
			fs.mkdirSync incPath.join '/'
		catch e
			if e.code is 'EEXIST'
				console.log "\tFolder #{incPath.join '/'} already exists" if conf.verbose or v
				continue
			console.error "Could not create #{incPath.join '/'}", e

utils.trailingSlash = (path) ->
	unless path then return ""
	if path.slice(-1) is "/" then return path
	else return "#{path}/"
utils.timestamp = ->
	new Date().getTime()

utils.isDarwin = () ->
	return process.platform is 'darwin' or process.env['darwin'] == 'true'

utils.hexDump = (str, encoding=conf.encoding, splitOn=2) ->
	unless str then return str
	re = new RegExp("(.{1,#{splitOn}})", "g")
	console.log("Hex Length", new Buffer(str, encoding).toString('hex').length)
	new Buffer(str, encoding).toString('hex').split(re).join(" ")

#Utils based on other libraries
utils.encrypt = (clear_data, key, iv, encoding=conf.cipher.encoding, cipherType=conf.cipher.type) ->
	key = new Buffer key, encoding
	iv = new Buffer iv, encoding

	if Buffer.isBuffer clear_data
		clear_data_buffer = clear_data
	else clear_data_buffer = new Buffer clear_data, conf.encoding or "utf8"

	cipher = crypto.createCipheriv cipherType, key, iv 

	data = cipher.update clear_data_buffer, "binary", encoding or "base64"
	data += cipher.final encoding or "base64"
	
	#new Buffer(data, "binary").toString "base64"

utils.decrypt = (encrypted_data, key, iv, encoding=conf.cipher.encoding, cipherType=conf.cipher.type) ->
	key = new Buffer key, encoding
	iv = new Buffer iv, encoding

	if Buffer.isBuffer encrypted_data
		encrypted_data_buffer = encrypted_data
	else encrypted_data_buffer = new Buffer encrypted_data, encoding or "base64"

	encrypted_data_buffer = new Buffer encrypted_data, encoding or "base64"
	decipher = crypto.createDecipheriv cipherType, key, iv

	data = decipher.update encrypted_data_buffer, "binary", conf.encoding or "utf8"
	data += decipher.final conf.encoding or "utf8"

	#new Buffer(data, "binary").toString conf.encoding or "utf8"

# Wrapper around the 'cp -r' action
utils.copyAsset = (from, to, v) ->
	utils.ensureFolderExists to
	
	task = Q.defer()

	stat = fs.lstatSync from
	if not stat.isDirectory() and not stat.isFile()
		console.log 'No Asset at ', from
		task.promise
		return task.resolve ''

	# Launch the copy process
	c = cp.spawn 'cp', ['-rf', from, to]
	
	c.stdout.on 'data', (data) -> console.log "\t", data.toString() if conf.verbose
	c.stderr.on 'data', (data) -> console.log "\t", data.toString() if conf.verbose
	

	c.on 'exit', (code) ->	
		if code is 0
			console.log "\tAsset copied from (#{from}) to (#{to})" if conf.verbose or v
			task.resolve code
		else
			console.log "\tFailed to copy asset (#{from})"
			task.reject code

	task.promise

# Wrapper around the 'mv -f' action
utils.moveAsset = (from, to, v) ->
	a = to.split '/'
	a.pop()
	a = a.join '/'
	utils.ensureFolderExists a
	task = Q.defer()

	stat = fs.lstatSync from
	if not stat.isDirectory() and not stat.isFile()
		console.log 'No Asset at ', from
		task.promise
		return task.resolve ''

	# Launch the move process
	c = cp.spawn 'mv', ['-f', from, to]

	c.stdout.on 'data', (data) -> console.log "\t", data.toString() if conf.verbose
	c.stderr.on 'data', (data) -> console.log "\t", data.toString() if conf.verbose

	c.on 'exit', (code) ->	
		if code is 0
			console.log "\tAsset moved from (#{from}) to (#{to})" if conf.verbose or v
			task.resolve to
		else
			console.log "\tFailed to move asset (#{from})"
			task.reject code

	task.promise

# Wrapper around the 'rm -rf' action
utils.deleteAsset = (path, v) ->
	task = Q.defer()

	c = cp.spawn 'rm', ['-rf', path]

	c.stdout.on 'data', (data) -> console.log "\t", data.toString() if conf.verbose
	c.stderr.on 'data', (data) -> console.log "\t", data.toString() if conf.verbose

	c.on 'exit', (code) ->	
		if code is 0
			console.log "\tAsset deleted (#{path})" if conf.verbose or v
			task.resolve code
		else
			console.log "\tFailed to delete asset (#{path})"
			task.reject code

	task.promise

utils.copydir = (from, to) ->
	utils.ensureFolderExists to
	content = fs.readdirSync from

	for file in content
		fullPath = "#{from}/#{file}"		
		info = fs.lstatSync fullPath
		utils.copyAsset fullPath, to


utils.readdir = (path, recursive, sort) ->	
	files = []
	for file in fs.readdirSync path
		fullPath = "#{path}/#{file}"
		info = fs.lstatSync fullPath
		files.push fullPath if info.isFile() and file != ".DS_Store" and file != ".gitignore"
		files = files.concat utils.readdir fullPath, recursive if info.isDirectory() and recursive is on
	files = files.sort() if sort is on 
	files

utils.readFile = (path, parse) ->
	file = fs.readFileSync path, conf.encoding
	file = JSON.parse file if parse
	file

utils.newFileName = (filename) ->
	b = ''
	a = filename.split '.'
	if a.length > 1
		b = a.pop()
		filename = a.join '.'

	filename + utils.uuid() + b

utils.read_write = (from, to, options) ->
	opts = 
		from: from
		to: to
		ignore_files: []
		limit: 50
		final: ""
		initial: ""
		onRead: undefined
		onWrite: undefined
		onEnd: undefined
		verbose: false
	opts = utils.extend opts, options

	read_running = 0
	write_running = 0

	running = -> write_running + read_running
	final = -> 
		if opts.onEnd then opts.onEnd()
		console.log "\n\tDone making #{len} files in: ", ((new Date() - start)/1000), "secs\n" if conf.verbose or opts.verbose

	files = []
	files_to_write = []


	files = files.concat(utils.readdir f, true).filter((x)->
		for ignore in opts.ignore_files
			if x.split('/').pop() == ignore
				console.log "\t#{ignore} ignored" if conf.verbose or opts.verbose
				return false
		return true
	) for f in opts.from

	len = "#{files.length}"

	read_files = ->
		while running() < opts.limit and files.length > 0
			(() ->
				file = files.shift()
				return unless file isnt ''

				fs.readFile file, conf.encoding, (err, content) ->

					f = {path: file.split("/").shift(), content:content}
					e = if opts.onRead then opts.onRead content, file

					files_to_write.push e || f
					read_running--

					if files_to_write.length > 0 and running() < opts.limit then write_files()
					if files.length > 0 then read_files() else final() if running() is 0
				read_running++
			)()
	write_files = ->
		while running() < opts.limit and files_to_write.length > 0
			(() ->
				file = files_to_write.shift()
				return unless file isnt ''

				util.ensureFolderExists file.path

				fs.writeFile file.path, file.content, conf.encoding, ->

					if opts.onWrite then onWrite file
					write_running--

					if files.length > 0 and running() < opts.limit then read_files()
					if files_to_write.length > 0 then write_files() else final() if running() is 0
				write_running++
			)()
	start = new Date()
	read_files()

utils.lessMinify = (inputFiles, out, fromString=false, v) ->
	console.log "LESS Minification Started!" if conf.verbose or v
	utils.ensureFolderExists out if out?
	task = Q.defer()

	minify = (output, out) ->
		less.render output, (e, css) ->
			return task.reject e if e
			task.resolve css
			if out then fs.writeFile out, css, conf.encoding, ->
				console.log "LESS Minification Done! - #{out}\n" if conf.verbose or v
		task.promise

	return minify inputFiles, out if fromString

	utils.concatFiles(inputFiles).then(
		(output) -> minify output, out 
		(error) -> task.reject error; console.log error
	)
	task.promise

utils.cssMinify = (inputFiles, out, fromString = false, v) ->
	console.log "CSS Minification Started!" if conf.verbose or v
	utils.ensureFolderExists out if out?
	task = Q.defer()
	minify = (output, out) ->
		min = clean_css.process output
		task.resolve min
		if out then fs.writeFile out, min, conf.encoding, ->
			console.log "CSS Minification Done! - #{out}\n" if conf.verbose or v
		task.promise

	return minify inputFiles, out if fromString

	utils.concatFiles(inputFiles).then(
		(output) -> minify output, out 
		(error) -> task.reject error; console.log error
	)
	task.promise

utils.css_less_minify = (cssFiles, lessFiles, out, v) ->
	task = Q.defer()
	todo = []
	todo.push utils.cssMinify cssFiles if cssFiles?.length
	todo.push utils.lessMinify lessFiles, null, false, v if lessFiles?.length

	Q.all(todo).then(
		(output) ->
			if out and output[1]
				arr = out.split('/'); arr.pop()
				om = arr.join('/') + "/main.css"
				utils.ensureFolderExists om
				fs.writeFile om, output[1], conf.encoding
			utils.cssMinify(output.join("\n"), out, true, v).then task.resolve, task.reject
		(err) -> task.reject err
	)
	task.promise

# Generates a minified version of the developer build using uglify.js
utils.minify = (inputFiles, out, fromString = false, v) ->
	console.log "JS Minification Started!" if conf.verbose or v
	utils.ensureFolderExists out if out?
	task = Q.defer()

	min = uglify.minify inputFiles, {fromString: fromString}
	task.resolve min.code
	if out then fs.writeFile out, min.code, conf.encoding, ->
		console.log "JS Minification Done! - #{out}\n" if conf.verbose or v

	task.promise


utils.optimizeImages = (dirPath, v) ->
	oi = cp.spawn 'pulverize', ['-aR', dirPath]
	task = Q.defer()
	
	console.log 'Optimizing Images...' if conf.verbose or v

	oi.on 'exit', (code) ->
		console.log 'Image Optimization Done!', 'Exit Code', code if conf.verbose or v
		task.resolve(code)
	task.promise

utils.watchAndUpdate = (paths, callback, options) ->
	opts = 
		ignorePatterns: true
		ignoreHiddenFiles: true
		interval:1000
		verbose: false
	utils.extend opts, options if options

	if typeof paths is 'string' then paths = [paths]

	alert = (args, callback) =>
   		console.log "\n", args[1], 'as been', args[0]+'d' if conf.verbose or opts.verbose
    	callback?.apply @, args 

  	watchr.watch
  		paths: paths
  		listener: (eventName,filePath,fileCurrentStat,filePreviousStat) ->
  			alert arguments, callback
  		next: console.log 'Watching (press Ctrl+C to stop)...'
  		ignorePatterns: opts.ignorePatterns
  		ignoreHiddenFiles: opts.ignoreHiddenFiles
  		interval: opts.interval


# Reads a set of files and returns them as a concatenated string
utils.concatFiles = (inputFiles, fn, v) ->
	if typeof inputFiles is 'string' then inputFiles = [inputFiles]
	if typeof fn isnt 'function' then fn = (file) -> file

	task = Q.defer()
	console.log "\tReading #{f}..." if conf.verbose or v

	# Concatenate the source files
	output = ("\n\n/**#{f}**/\n" + (fn (fs.readFileSync f, conf.encoding).trim()) for f in inputFiles)
	
	task.resolve output.join "\n"
	task.promise

utils.compileFiles = (inputFiles, fn, v) ->
	if typeof inputFiles is 'string' then inputFiles = [inputFiles]
	if typeof fn isnt 'function' then fn = (file) -> file

	task = Q.defer()
	# Queue up the compilation tasks
	compilation = Q.all (fn file, v for file in inputFiles)
	# When the compilation is complete...
	compilation.then(
	  # Concatenate the outputs and return
		(output) -> task.resolve output.join "\n",
		# (or throw an error)
		-> console.log arguments; task.reject arguments
	)
	# Return the promise
	task.promise

# Reads a CoffeeScript file and returns it as a compiled JS string
utils.compileCoffee = (inputFile, v) ->
	console.log "\tCompiling #{inputFile}" if conf.verbose or v
	# Launch the compilation process
	coffee = cp.spawn 'coffee', ['-cp', inputFile]
	output = ''
	# Make a promise
	deferred = Q.defer()
	done = no
	exitCode = no
	coffee.stderr.on 'data', (data) -> console.log data.toString(); process.exit(1)
	# Buffer the compilation output
	coffee.stdout.on 'data', (data) -> 
		output += data.toString()
		complete exitCode if done and useDarwinMode()

	complete = (code) ->
		# ...return!
		if code is 0
			deferred.resolve "\n\n/**#{inputFile}**/\n#{output}"
		else
			console.log "\tFailed to compile #{inputFile}; exit code:", code
			deferred.reject code

	# When it's finished...
	coffee.on 'exit', (code) ->
		complete code
		###
		if utils.isDarwin() then complete code
		else done = yes; exitCode = code;
		###

	# Return the promise
	deferred.promise

# Reads a template file and returns it as a compiled JS string
utils.compileTemplate = (inputFile, v) ->
	# Generate the template name from the file path
	[_path..., file] = inputFile.split '/'
	[namechunks..., engine, language] = file.split '.'
	name = namechunks.join '_'
	console.log "\tCompiling #{name} - (#{inputFile})" if conf.verbose or v

	# Make a promise
	deferred = Q.defer()

	# Try to read the template file
	try
		fileContent = fs.readFileSync inputFile, conf.encoding
	catch e
		console.error "Could not read template file: ", inputFile, e
		deferred.reject e

	# Try to compile the template
	try
		deferred.resolve "\n\n/**#{inputFile}**/\n" + dust.compile fileContent, name
	catch e
		console.error "Could not compile template: ", inputFile, e
		deferred.reject e

	# Return the promise
	deferred.promise

utils.makeManifest = (params, v) ->

	console.log 'Creating Manifest...' if conf.verbose or v
	utils.ensureFolderExists params.path

	try
		params.version = params.version()
	catch error
		params.version = utils.uuid()
    
	aFileList = []
	temp = []

	aFileList = utils.readdir params.path, true
	for i, x of aFileList
		arr = x.split "/"; arr.shift()
		aFileList[i] = arr.join "/"

	contents = "CACHE MANIFEST\n"
	contents += "# version #{params.version}\n\n"
  
	#Cache section
	contents += "CACHE:\n"
	if params.include
		aFileList = utils.filterArray aFileList, params.include, true

	if params.exclude
		aFileList = utils.filterArray aFileList, params.exclude 
	
	aFileList.forEach (item) ->
		contents += item + "\n"

	#Network section
	if params.network
		contents += "\nNETWORK:\n"
		params.network.forEach (item) ->
			contents += item + "\n"

	#Fallback section
	if params.fallback
		contents += "\nFALLBACK:\n"
		params.fallback.forEach (item) ->
			contents += item + "\n"

	task = Q.defer()
	fs.writeFile params.path + "/#{params.filename}.appcache", contents, (err) ->
		throw err  if err
		task.resolve "#{params.filename}.appcache"

	#only if no htaccess already 
	#fs.writeFile params.path + "/" + ".htaccess", "AddType text/cache-manifest .manifest", (err) ->
		#throw err  if err

	console.log "Cache manifest file generated : #{params.filename}.appcache\n" if conf.verbose or v
	console.log "You have to update <html> tag : <html manifest=\"/#{params.filename}.manifest\">" if conf.verbose or v
	console.log contents if conf.verbose or v
	task.promise

utils.makeCoffee = (n) ->

	j2c = requireOne 'js2coffee';

	console.log '\nLets Make Some Coffee Now Shall We!'
	console.log '\tBoiling Water....'
		
	files = []
	files_to_write = []

	limit = 50
	read_running = 0
	write_running = 0
	running = -> write_running + read_running
	final = -> console.log "\n\tPhew! Done making #{len} coffees in: ", ((new Date() - start)/1000), "secs\n"

	files = files.concat(utils.readdir f, true).filter((x)->
		return (x.indexOf("js") isnt -1 and x.indexOf("coffee") is -1 and x.indexOf("parser") is -1)
	) for f in n	

	len = "#{files.length}"
	console.log "\tSo we are making coffee for #{files.length}!\n"	

	change_to_coffee = (file, write_to, content) ->
		console.log "\tAdding Milk    to      #{file}"
		coffee_file = j2c.build content
		files_to_write.push {name:write_to, coffee:coffee_file}

	read_files = ->
		while running() < limit and files.length > 0
			(() ->
				file = files.shift()
				return unless file isnt ''
				console.log "\tGrinding Beans for     #{file}"
				fs.readFile file, conf.encoding, (err, content) ->

					fold_name = file.split('/').shift()
					new_file = file.replace(fold_name, "#{fold_name}_coffee") + ".coffee"
					change_to_coffee file, new_file, content
					read_running--

					if files_to_write.length > 0 and running() < limit then write_files()
					if files.length > 0 then read_files() else final() if running() is 0
				read_running++
			)()
	write_files = ->
		while running() < limit and files_to_write.length > 0
			(() ->
				file = files_to_write.shift()
				return unless file isnt ''

				utils.ensureFolderExists file.name, true
				console.log "\tPouring coffee into    #{file.name}" 
				fs.writeFile file.name, file.coffee, conf.encoding, ->

					console.log("\tHere is your coffee    #{file.name}")
					write_running--

					if files.length > 0 and running() < limit then read_files()
					if files_to_write.length > 0 then write_files() else final() if running() is 0
				write_running++
			)()
	start = new Date()
	read_files()

utils.sql_escape = (str) ->
	str.replace /[\0\x08\x09\x1a\n\r"'\\\%]/g, (char) ->
		switch char
			when "\u0000" then "\\0"
			when "\b" then "\\b"
			when "\t" then  "\\t"
			when "\u001a" then "\\z"
			when "\n" then "\\n"
			when "\r" then "\\r"
			when "\"", "'", "\\", "%" then "\\" + char 
			else "\\" + char

utils.responseServer = (opts) ->
	http = utils.requireOne 'http'

	server = http.createServer (req, res) ->
		requestBody = ""
		head = 
			"Content-Type" : "application/json"
		body = -> {data: requestBody}

		req.setEncoding conf.encoding

		req.on "data", (chunk) ->
			requestBody += chunk

		req.on "end", ->
			res.writeHead 200, head
			res.end body()

	server.listen conf.port, conf.host
	console.log "Server Running on #{conf.host}:#{conf.port} (press Ctrl+C to stop)..."

utils.skeleton = (struct, path) ->
	def = 
		res: 
			html: ["index.html", "index.dev.html"]
			images:[]
			php: []
			tpl: []
			lib: []
			css: []
		src:[]
		test: []
	structure = struct or def

	for folder, sub of structure

		if utils.isString sub 
			new_path = "#{path}/#{sub}"
			fs.openSync new_path, 'w' unless fs.existsSync new_path
		else
			if path then new_path = "#{path}/#{folder}"
			else new_path = "#{folder}" 

			utils.ensureFolderExists new_path
			arguments.callee sub, new_path 	