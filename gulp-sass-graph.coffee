fs = require 'fs'
path = require 'path'
gutil = require 'gulp-util'
through = require 'through2'
glob = require 'glob'
File = require 'vinyl'

module.exports = (loadPaths) ->
	graph = {}

	loadPaths = if loadPaths instanceof Array then loadPaths else [loadPaths]

	# adds a sass file to a graph of dependencies
	addToGraph = (filepath, contents, parent) ->
		entry = graph[filepath] = graph[filepath] or {
			path: filepath,
			imports: [],
			importedBy: [],
			modified: fs.statSync(filepath).mtime
		}
		imports = sassImports(contents())
		cwd = path.dirname(filepath)

		for i of imports
			resolved = sassResolve(imports[i], loadPaths.concat([cwd]))
			return false unless resolved

			# recurse into dependencies if not already enumerated
			unless resolved in entry.imports
				entry.imports.push(resolved)
				importedFilePath = if path.extname(resolved) then resolved else resolved + ".scss"
				importedFileContents = -> fs.readFileSync(importedFilePath, 'utf8')
				addToGraph(resolved, importedFileContents, filepath)

		# add link back to parent
		entry.importedBy.push(parent) if parent

		return true

	# visits all files that are ancestors of the provided file
	visitAncestors = (filepath, callback, visited = []) ->
		edges = graph[filepath].importedBy

		for i of edges
			unless edges[i] in visited
				visited.push(edges[i])
				callback(graph[edges[i]])
				visitAncestors(edges[i], callback, visited)

	# parses the imports from sass
	sassImports = (content) ->
		re = /\@import (["'])(.+?)\1;/g
		results = []

		# strip comments
		content = new String(content).replace(/\/\*.+?\*\/|\/\/.*(?=[\n\r])/g, '')

		# extract imports
		while (match = re.exec(content))
			importArgument = match[2]
			filePath = importArgument.replace(/^\.\//,'')
			results.push(filePath)

		results
			.filter (x) -> x isnt 'compass'
			.filter (x) -> not /compass\/.*/.test(x)

	# resolve a relative path to an absolute path
	sassResolve = (path, loadPaths) ->
		for p in loadPaths
			ext = if /\.(scss|sass)$/i.test(path) then "" else ".scss"

			scssPath = "#{p}/#{path}#{ext}"

			dotdotPattent = /[^\.\/]+\/\.\.\//g
			while dotdotPattent.test(scssPath)
				scssPath = scssPath.replace(dotdotPattent, '')

			return scssPath if fs.existsSync(scssPath) # TODO: replace with fs.accessSync

			partialPath = scssPath.replace(/\/([^\/]*)$/, '/_$1');
			return partialPath if fs.existsSync(partialPath)

		console.warn("failed to resolve %s from ", path, loadPaths)
		return false

	# build the graph
	loadPaths
	.forEach (path) ->
		glob.sync(path + "/**/*.scss", {})
		.forEach (file) ->
			unless addToGraph(file, -> fs.readFileSync(file, 'utf8'))
				console.warn("failed to add %s to graph", file)

	pipeFn = (conditions) ->
		through.obj (file, enc, cb) ->
			if file.isNull()
				@push(file)
				return cb()

			if file.isStream()
				@emit 'error', new gutil.PluginError('gulp-sass-graph', 'Streaming not supported')
				return cb()

			fs.stat file.path, (err, stats) =>
				if err
					# pass through if it doesn't exist
					if err.code is 'ENOENT'
						@push(file);
						return cb()

					@emit 'error', new gutil.PluginError('gulp-sass-graph', err)
					@push(file)
					return cb()

				relativePath = file.path
					.substr(file.cwd.length + 1)
					.replace(/\\/g, '/')

				unless graph[relativePath]
					addToGraph relativePath, -> file.contents.toString('utf8')

				if relativePath.split('/').pop()[0] isnt '_'
					if !conditions or conditions (relativePath)
						console.log("processing %s", relativePath)
						@push(file)

				# push ancestors into the pipeline
				visitAncestors relativePath, (node) =>
					ancestorPath = path.normalize "#{file.cwd}/#{node.path}"
					ancestorFile = new File
						contents: new Buffer(fs.readFileSync(ancestorPath))
						cwd: file.cwd
						base: file.base
						path: node.path

					if (!conditions or conditions (node.path))
						console.log("processing %s", node.path)
						@push(ancestorFile);

				cb()

	alreadyPushed = []

	return {
		graph: graph
		endless: pipeFn()
		singleRun: pipeFn (filePath) ->
			unless filePath in alreadyPushed
				alreadyPushed.push filePath
				return true
			return false
	}
