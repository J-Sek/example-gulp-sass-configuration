'use strict';
var fs = require('fs');
var path = require('path');
var gutil = require('gulp-util');
var through = require('through2');
var _ = require('lodash');
var path = require('path');
var glob = require('glob');
var File = require('vinyl');

module.exports = function (loadPaths) {
	var graph = {}

	// adds a sass file to a graph of dependencies
	var addToGraph = function (filepath, contents, parent) {
		var entry = graph[filepath] = graph[filepath] || {
			path: filepath,
			imports: [],
			importedBy: [],
			modified: fs.statSync(filepath).mtime
		};
		var imports = sassImports(contents());
		var cwd = path.dirname(filepath)

		for (var i in imports) {
			var resolved = sassResolve(imports[i], loadPaths.concat([cwd]));
			if (!resolved) return false;

			// recurse into dependencies if not already enumerated
			if (!_.contains(entry.imports, resolved)) {
				entry.imports.push(resolved);
				addToGraph(resolved, function () {
					return fs.readFileSync((path.extname(resolved) != "" ?
						resolved : resolved + ".scss"), 'utf8')
				}, filepath);
			}
		}

		// add link back to parent
		if (parent != null) {
			entry.importedBy.push(parent);
		}

		return true;
	}

	// visits all files that are ancestors of the provided file
	var visitAncestors = function (filepath, callback, visited) {
		visited = visited || [];
		var edges = graph[filepath].importedBy;

		for (var i in edges) {
			if (!_.contains(visited, edges[i])) {
				visited.push(edges[i]);
				callback(graph[edges[i]]);
				visitAncestors(edges[i], callback, visited);
			}
		}
	}

	// parses the imports from sass
	var sassImports = function (content) {
		var re = /\@import (["'])(.+?)\1;/g,
			match = {},
			results = [];

		// strip comments
		content = new String(content).replace(/\/\*.+?\*\/|\/\/.*(?=[\n\r])/g, '');

		// extract imports
		var importArgument, filePath;
		while (match = re.exec(content)) {
			importArgument = match[2];
			filePath = importArgument.replace(/^\.\//,'');
			results.push(filePath);
		}

		return results
			.filter(function (x) { return x !== 'compass'; })
			.filter(function (x) { return !/compass\/.*/.test(x); });
	};

	// resolve a relative path to an absolute path
	var sassResolve = function (path, loadPaths) {
		for (var p in loadPaths) {
			var scssPath =
				(loadPaths[p] + "/" + path + (/\.scss$/i.test(path) ? "" : ".scss"))
					.replace(/[^\.\/]+\/\.\.\//g, '')
					.replace(/[^\.\/]+\/\.\.\//g, '')
					.replace(/[^\.\/]+\/\.\.\//g, '')
					; // cleanup path from "abc/../"


			if (fs.existsSync(scssPath)) {
				return scssPath;
			}
			var partialPath = scssPath.replace(/\/([^\/]*)$/, '/_$1');
			if (fs.existsSync(partialPath)) {
				return partialPath
			}
		}

		console.warn("failed to resolve %s from ", path, loadPaths)
		return false;
	}

	// builds the graph
	_(loadPaths).forEach(function (path) {
		_(glob.sync(path + "/**/*.scss", {})).forEach(function (file) {
			if (!addToGraph(file, function () { return fs.readFileSync(file) })) {
				console.warn("failed to add %s to graph", file)
			}
		});
	});


var pipeFn = function (conditions) {
	return through.obj(function (file, enc, cb) {
		if (file.isNull()) {
			this.push(file);
			return cb();
		}

		if (file.isStream()) {
			this.emit('error', new gutil.PluginError('gulp-sass-graph', 'Streaming not supported'));
			return cb();
		}

		fs.stat(file.path, function (err, stats) {
			if (err) {
				// pass through if it doesn't exist
				if (err.code === 'ENOENT') {
					this.push(file);
					return cb();
				}

				this.emit('error', new gutil.PluginError('gulp-sass-graph', err));
				this.push(file);
				return cb();
			}

			var relativePath = file.path.substr(file.cwd.length + 1).replace(/\\/g, '/');

			if (!graph[relativePath]) {
				addToGraph(relativePath, function () { return file.contents.toString('utf8') });
			}

			if (relativePath.split('/').pop()[0] !== '_') {
				if (!conditions || conditions (relativePath))
				{
					console.log("processing %s", relativePath);
					this.push(file);
				}
			}

			// push ancestors into the pipeline
			visitAncestors(relativePath, function (node) {
				//, which depends on %s", node.path, relativePath)
				var ancestorPath = file.cwd + "\\" + node.path.replace(/\//g, '\\');
				var ancestorFile = new File({
					contents: new Buffer(fs.readFileSync(ancestorPath)),
					cwd: file.cwd,
					base: file.base,
					path: node.path
				});
				if (!conditions || conditions (node.path))
				{
					console.log("processing %s", node.path)
					this.push(ancestorFile);
				}
			}.bind(this));

			cb();
		}.bind(this));
	});
}

var alreadyPushed = {};

return {
	graph: graph,
	endless: pipeFn(),
	pipe: pipeFn(function(filePath) {
		if (!alreadyPushed[filePath]) {
			alreadyPushed[filePath] = true;
			return true;
		}
		else return false;
	})
	};
};
