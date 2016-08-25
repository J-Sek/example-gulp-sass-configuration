# TODO

The main goal is to prevent recompilation wasting ~20seconds every F5 hit.
Additionally I'll try to integrate few tweaks making workflow less shameful in 2016.

## Changes

1. Add [gulp-sass-graph](https://www.npmjs.com/package/gulp-sass-graph)
1. Add livereload if it might work with ASP.NET
1. Accept --force or add 'clean' task
1. Add *.csproj with configuration
1. Add gulp-notify to inform about compilation errors

## Tests

1. Automatic test of caching
    - Add commands to prove execution times are lower
1. Automatic test to measure watch delay
1. Automatic test by calling msbuild

## Required fixes in gulp-sass-graph/index.js:126

```(js)
var relativePath = file.path.substr(file.cwd.length+1).replace(/\\/g,'/');

if(!graph[relativePath]) {
    addToGraph(relativePath, function() { return file.contents.toString('utf8') });
}

if (relativePath.split('/').pop()[0] !== '_') {
    console.log("processing %s", relativePath);
    this.push(file);
}

// push ancestors into the pipeline
visitAncestors(relativePath, function(node){
    console.log("processing %s", node.path)
    //, which depends on %s", node.path, relativePath)
    var ancestorPath = file.cwd + "\\" + node.path.replace(/\//g,'\\');
    this.push(new File({
        contents: new Buffer(fs.readFileSync(ancestorPath)),
        cwd: file.cwd,
        base: file.base,
        path: node.path
    }));
}.bind(this));
```