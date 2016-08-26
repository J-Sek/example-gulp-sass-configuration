gulp = require 'gulp'
$ = require('gulp-load-plugins')()
compass = require 'compass-importer'
execSync = require('child_process').execSync
watch = require 'glob-watcher'
sassGraph = require './gulp-sass-graph'

# ##########################
# Constants
#

CSS_DIR = 'Content/Css'
SASS_DIR = 'Content/Sass'
SASS_PATHS = [
    'Content/Sass/base/**/*.scss'
    '!Content/Sass/base/_bootstrap/**/*.scss'
    'Content/Sass/components/**/*.scss'
    'Content/Sass/pages/**/*.scss'
]

# ##########################
# Utils
#

parseArgumentValue = (pattern) ->
    args = process.argv.toString()
    valueRegExp = new RegExp(pattern)
    return args.match(valueRegExp)[1] if valueRegExp.test(args)

getArgument = (flag, wrapFn) ->
    value = parseArgumentValue(flag + "=[']([^']*)[']")
    return unless value
    if wrapFn then wrapFn(value) else value

cleanAttributesSync = (path) ->
    execSync("attrib -r " + path + "\\*.* /s");


# ##########################
# Parsing arguments
#

SASS_FILES = getArgument('--scope', (dir) => "Content/Sass/#{dir}/**/*.scss") or SASS_PATHS
SASS_OUTPUT_STYLE = getArgument('--style') or 'expanded'

# ##########################
# Tasks
#

gulp.task 'sass', (done) ->
    cleanAttributesSync CSS_DIR

    sassLoadPaths = SASS_DIR
    gulp.src SASS_FILES, base: SASS_DIR
        .pipe $.plumber()
        .pipe $.sass
            importer: compass
            outputStyle: SASS_OUTPUT_STYLE
            loadPath: sassLoadPaths
        .on 'error', $.sass.logError
        .pipe gulp.dest CSS_DIR

gulp.task 'watch_old', ->
    gulp.watch SASS_FILES, ['sass']

gulp.task 'watch:sass', ->
    sassLoadPaths = SASS_DIR
    $.watch SASS_DIR + '/**/*.scss'
        .pipe $.plumber()
        .pipe sassGraph [sassLoadPaths]
        .pipe $.sass
            importer: compass
            outputStyle: SASS_OUTPUT_STYLE
            loadPath: sassLoadPaths
        # .pipe $.notify 'Sass compiled <%= file.relative %>'
        .pipe gulp.dest CSS_DIR
        # .pipe livereload()

# ##########################
# Test
#

gulp.task 'test', ->
    gulp.src 'test/**/*.coffee', read: false
        .pipe $.plumber()
        # $.notify 'Tests failed <%= error.message %>'
        .pipe $.mocha reporter: 'progress'

gulp.task 'watch:test', ->
    gulp.watch [
        '*.js'
        '*.coffee'
        'test/**/*.coffee'
    ], ['test']