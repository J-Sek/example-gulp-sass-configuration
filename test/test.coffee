fs = require 'fs'
rimraf = require 'rimraf'
expect = require('chai').expect
spawn = require('child_process').spawn

# describe '[example]', ->
#     describe 'test', ->
#         it 'should work as expected', ->
#             expect(true).to.equal(true)

log = () ->
# log = console.log

testWatching = ({partialPath, content, changeFn, expectFn, next, delay}) ->

    partialContent = content
    partialNewContent = changeFn content

    # Setup enviromnent
    rimraf 'Content/Css', (err) ->
        throw err if err

        fs.writeFileSync partialPath, partialContent, 'utf8'

        # Exec 'gulp watch'
        gulp = spawn 'cmd', ['/K', 'node_modules\\.bin\\gulp watch:sass']

        gulp.on 'exit', (code) ->
            if code > 1
                throw new Error 'Gulp process exited with code ' + code
            log 'Gulp process closed'

        gulp.stdout.on 'data', (data) -> log("stdout: #{data}")
        gulp.stderr.on 'data', (data) ->
            log("stderr: #{data}")
            throw new Error 'Gulp process should not print any errors'

        # Wait in stdout and verify output
        setTimeout ->

            # Change something
            fs.writeFileSync partialPath, partialNewContent, 'utf8'

            log("Waiting 6000ms for demo.scss")
            setTimeout ->
                log("Reading demo.scss")
                _err = null
                try
                    expect(-> fs.accessSync 'Content/Css/base/demo.css').to.not.throw(Error)
                    fs.accessSync 'Content/Css/base/demo.css'
                    newContent = fs.readFileSync 'Content/Css/base/demo.css', 'utf8'
                    expectFn(newContent)
                catch err
                    console.log 'Error:', _err

                    _err = err
                finally
                    # Terminate watching process
                    spawn 'taskkill', ['/F','/T','/PID',gulp.pid]

                throw _err if _err
                next()
            , delay
        , delay


describe '[Watch]', ->
    describe 'parsing imports', ->
        it 'should accept exact filename', (done) ->
            @timeout 14000

            testWatching
                partialPath: 'Content/Sass/base/_colors.scss'
                content: '''
                    $default-color: red;
                    $bg-color: #eee;
                '''
                changeFn: (content) -> content.replace 'red', 'gray'
                expectFn: (content) -> expect(content).to.contain('gray')
                next: done
                delay: 5000

    describe 'parsing imports', ->
        it 'should normalize relative import path', (done) ->
            @timeout 14000

            testWatching
                partialPath: 'Content/Sass/base/_fonts.scss'
                content: '''
                    @import url(\'//fonts.googleapis.com/css?family=Open+Sans\');
                    $base-font: \'Open Sans\', sans-serif;
                '''
                changeFn: (content) -> content.replace 'Open Sans', 'Raleway'
                expectFn: (content) -> expect(content).to.contain('Raleway')
                next: done
                delay: 5000
