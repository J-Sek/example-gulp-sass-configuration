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

executeCompilation = (next) ->
    pattern = /Finished 'sass' after ([0-9\.]+) s/
    gulp = spawn 'cmd', ['/K', 'node_modules\\.bin\\gulp sass --scope=\'base/_bootstrap\'']

    gulp.on 'exit', (code) ->
        if code > 1
            throw new Error 'Gulp process exited with code ' + code
        log 'Gulp process finished'

    gulp.stdout.on 'data', (data) ->
        log("stdout: #{data}")
        if pattern.test data
            timeParsedFromGulpLog = parseFloat data.toString().match(pattern)[1]
            # Terminate process
            spawn 'taskkill', ['/F','/T','/PID',gulp.pid]
            next timeParsedFromGulpLog

    gulp.stderr.on 'data', (data) ->
        log("stderr: #{data}")
        throw new Error 'Gulp process should not print any errors'

measureCompilation = () ->
    new Promise (resolve, reject) ->
        startTime = new Date()
        executeCompilation (loggedTime) ->
            log("resolve with #{loggedTime} s")
            endTime = new Date()
            elapsedTime = endTime - startTime
            resolve([elapsedTime, loggedTime])

describe '[Build]', ->
    describe 'caching', ->
        it 'should run significantly faster if all files are already compiled', ->
            # Setup enviromnent
            @timeout 15000

            rimrafAsync '.sass-cache'
            .then rimrafAsync 'Content/Css'
            .then ->
                fs.writeFileSync 'Content/Sass/base/_bootstrap/big.scss', [0..40].map(-> "@import 'bootstrap';").join '\n'

                # Measure first run
                measureCompilation()
                .then (firstRunTimes) ->
                # Measure second run
                    measureCompilation()
                    .then (secondRunTimes) ->
                # Compare
                        console.log "firstRunTime: #{firstRunTimes[1]} s"
                        console.log "secondRunTime: #{secondRunTimes[1]} s"
                        ratio = secondRunTimes[1] / firstRunTimes[1]
                        expect(ratio).to.be.closeTo(0.1, 0.2)

        # it 'should run compile missing files', ->
        # it 'should compile all files if out directory is missing', ->
        # it 'should run compile if there are any changes to partials', ->
