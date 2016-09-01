gulp = require 'gulp'
$ = require('gulp-load-plugins')()
compass = require 'compass-importer'
execSync = require('child_process').execSync
watch = require 'glob-watcher'
sassGraph = require './gulp-sass-graph'
FileCache = require 'gulp-file-cache'
del = require 'del'
{normalize} = require 'path'

# ##########################
# Constants
#

CSS_DIR = 'Content/Css'
SASS_DIR = 'Content/Sass'
SASS_CACHE = '.sass-cache'
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
    value = parseArgumentValue(flag + "=['\"]?([^']*)['\"]?")
    return unless value
    if wrapFn then wrapFn(value) else value

cleanAttributesSync = (path) ->
    if /^win/.test(process.platform)
        execSync("attrib -r " + path + "\\*.* /s");


# ##########################
# Parsing arguments
#

SASS_FILES = getArgument('--scope', (dir) => "Content/Sass/#{dir}/**/*.scss") or SASS_PATHS
SASS_OUTPUT_STYLE = getArgument('--style') or 'expanded'

# ##########################
# Tasks
#

gulp.task 'build:sass', (done) ->
    cleanAttributesSync CSS_DIR

    cache = new FileCache(SASS_CACHE)

    gulp.src SASS_FILES, base: SASS_DIR
        .pipe $.plumber()
        .pipe cache.filter()
        .pipe cache.cache()
        .pipe sassGraph([SASS_DIR]).singleRun
        .pipe $.sass
            importer: compass
            outputStyle: SASS_OUTPUT_STYLE
            loadPath: SASS_DIR
        .on 'error', $.sass.logError
        .pipe gulp.dest CSS_DIR

gulp.task 'clean:sass', (done) ->
    del [
        CSS_DIR
        SASS_CACHE
    ]

gulp.task 'rebuild:sass', gulp.series('clean:sass', 'build:sass')

gulp.task 'watch:sass:old', ->
    gulp.watch SASS_FILES, gulp.series 'build:sass'

gulp.task 'watch:sass', ->
    $.watch SASS_DIR + '/**/*.scss'
        .pipe $.plumber()
        .pipe sassGraph([SASS_DIR]).endless
        .pipe $.sass
            importer: compass
            outputStyle: SASS_OUTPUT_STYLE
            loadPath: SASS_DIR
        # .pipe $.notify 'Sass compiled <%= file.relative %>'
        .pipe gulp.dest CSS_DIR
        # .pipe livereload()

# ##########################
# Test
#

gulp.task 'test:unit', ->
        gulp.src 'test/unitTest.coffee', read: false
            # $.notify 'Tests failed <%= error.message %>'
            .pipe $.mocha reporter: 'progress'

gulp.task 'copy:bootstrap', ->
    gulp.src 'node_modules/bootstrap-sass/assets/stylesheets/**/*.*'
        .pipe gulp.dest 'Content/Sass/base/_bootstrap'

gulp.task 'test:cache', ->
        gulp.src 'test/cachingTest.coffee', read: false
            .pipe $.mocha reporter: 'progress'

gulp.task 'test:watch', ->
        gulp.src 'test/watchingTest.coffee', read: false
            .pipe $.mocha reporter: 'progress'

gulp.task 'test', gulp.series.apply gulp, [
        'test:unit'
        'copy:bootstrap'
        'test:cache'
        'test:watch'
    ]

gulp.task 'watch:test', ->
    gulp.watch [
        '*.js'
        '*.coffee'
        'test/**/*.coffee'
    ], ['test:unit']
