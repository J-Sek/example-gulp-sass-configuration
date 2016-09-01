fs = require 'fs'
rimraf = require 'rimraf'
expect = require('chai').expect
{shell} = require 'execa'

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
    gulp = shell 'gulp build:sass --scope=\'base/_bootstrap\''

    gulp.then ({stdout}) ->
        log("stdout: #{stdout}")
        if patternS.test stdout
            timeParsedFromGulpLog = parseFloat stdout.toString().match(patternS)[1]
        else if patternMs.test stdout
            timeParsedFromGulpLog = parseFloat(stdout.toString().match(patternMs)[1]) / 1000
        else
            return
        # Terminate process (if windows?)
        # spawn 'taskkill', ['/F','/T','/PID',gulp.pid]
        # shell "kill -9 #{gulp.pid}"
        next timeParsedFromGulpLog

    gulp.catch (err) ->
        log("stderr: #{err}")
        throw new Error 'Gulp process should not print any errors'
    return

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
                    , [0..15].map(-> "@import 'bootstrap';").join '\n'

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
