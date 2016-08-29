fs = require 'fs'
rimraf = require 'rimraf'
expect = require('chai').expect
spawn = require('child_process').spawn

log = () ->
#log = console.log

rimrafAsync = (path) ->
    new Promise (resolve, reject) ->
        rimraf path, (err) ->
            if err
                reject err
            else
                resolve()

executeCompilation = (taskName, next) ->
    patternS = new RegExp("Finished '#{taskName}' after ([0-9\.]+) s")
    patternMs = new RegExp("Finished '#{taskName}' after ([0-9]+) ms")
    gulp = spawn 'cmd', ['/K', 'node_modules\\.bin\\gulp build:sass --scope=\'base/_bootstrap\'']

    gulp.on 'exit', (code) ->
        if code > 1
            throw new Error 'Gulp process exited with code ' + code
        log 'Gulp process finished'

    gulp.stdout.on 'data', (data) ->
        log("stdout: #{data}")
        if patternS.test data
            timeParsedFromGulpLog = parseFloat data.toString().match(patternS)[1]
        else if patternMs.test data
            timeParsedFromGulpLog = parseFloat(data.toString().match(patternMs)[1]) / 1000
        else
            return
        # Terminate process
        spawn 'taskkill', ['/F','/T','/PID',gulp.pid]
        next timeParsedFromGulpLog

    gulp.stderr.on 'data', (data) ->
        log("stderr: #{data}")
        throw new Error 'Gulp process should not print any errors'

measureCompilation = (taskName) ->
    new Promise (resolve, reject) ->
        startTime = new Date()
        executeCompilation taskName, (loggedTime) ->
            log("resolve with #{loggedTime} s")
            endTime = new Date()
            elapsedTime = endTime - startTime
            resolve([elapsedTime, loggedTime])

describe '[Build]', ->
    describe 'caching', ->
        it 'should run significantly faster if all files are already compiled', ->
            # Setup enviromnent
            @timeout 30000

            taskName = 'build:sass'

            rimrafAsync '.sass-cache'
            .then rimrafAsync 'Content/Css'
            .then ->
                fs.writeFileSync 'Content/Sass/base/_bootstrap/big.scss'
                    , [0..40].map(-> "@import 'bootstrap';").join '\n'

                # Measure first run
                measureCompilation(taskName)
                .then (firstRunTimes) ->
                # Measure second run
                    measureCompilation(taskName)
                    .then (secondRunTimes) ->
                # Compare
                        log "firstRunTime: #{firstRunTimes[1]} s"
                        log "secondRunTime: #{secondRunTimes[1]} s"
                        ratio = secondRunTimes[1] / firstRunTimes[1]
                        expect(ratio).to.be.closeTo(0.1, 0.2)

        # it 'should run compile missing files', ->
        # it 'should compile all files if out directory is missing', ->
        # it 'should run compile if there are any changes to partials', ->
