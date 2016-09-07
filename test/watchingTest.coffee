fs = require 'fs'
rimraf = require 'rimraf'
expect = require('chai').expect
{shell} = require 'execa'

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
        gulp = shell 'gulp watch:sass'

        gulp.then ({stdout}) ->
            log("stdout: #{stdout}")

        gulp.catch (err) ->
            log("stderr: #{err}")
            throw new Error 'Gulp process should not print any errors'

        onFinished = ->
            log("Reading demo.scss")
            _err = null
            try
                expect(-> fs.accessSync 'Content/Css/base/demo.css').to.not.throw(Error)
                fs.accessSync 'Content/Css/base/demo.css'
                newContent = fs.readFileSync 'Content/Css/base/demo.css', 'utf8'
                expectFn(newContent)
            catch err
                _err = err
            finally
                # Terminate watching process
                # shell 'taskkill', ['/F','/T','/PID',gulp.pid]
                # shell "kill -9 #{gulp.pid}"
                gulp.kill()

            throw _err if _err
            next()

        # Wait in stdout and verify output
        setTimeout ->
            # Change something
            fs.writeFileSync partialPath, partialNewContent, 'utf8'
            log("Waiting #{delay}ms for demo.scss")
            setTimeout onFinished, delay
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

        it 'should normalize relative import path', (done) ->
            @timeout 14000

            testWatching
                partialPath: 'Content/Sass/base/_fonts.scss'
                content: '''
                    @import url('//fonts.googleapis.com/css?family=Open+Sans');
                    @import '../settings';
                    @import 'colors';
                    $base-font: 'Raleway', sans-serif;
                    body {
                        color: $default-color;
                        font-family: $base-font;
                        font-size: $base-font-size;
                    }
                '''
                changeFn: (content) -> content.replace 'Open Sans', 'Raleway'
                expectFn: (content) -> expect(content).to.contain('Raleway')
                next: done
                delay: 5000

        it 'should normalize ../ in import path', (done) ->
            @timeout 14000

            testWatching
                partialPath: 'Content/Sass/_settings.scss'
                content: '''
                $base-font-size: 16px !default;
                '''
                changeFn: (content) -> content.replace '16px', '20px'
                expectFn: (content) -> expect(content).to.contain('font-size: 20px')
                next: done
                delay: 5000
