expect = require('chai').expect
#sassGraph = require '../gulp-sass-graph'

log = () ->
# log = console.log

xdescribe '[Imports parser]', ->
    sut = null
    beforeEach ->
        sut = sassGraph ['Content/Sass']

    describe 'file paths', ->
        it 'should create graph by accepting import with ./', ->
            filePath = 'Content/Sass/base/demo.scss'
            partialPath = 'Content/Sass/base/_fonts.scss'
            expect(sut.graph[filePath]).to.exist;
            expect(sut.graph[filePath].imports).to.include(partialPath);

        it 'should create graph by accepting import with ../', ->
            filePath = 'Content/Sass/base/demo.scss'
            partialPath = 'Content/Sass/_settings.scss'
            expect(sut.graph[filePath]).to.exist;
            expect(sut.graph[filePath].imports).to.include(partialPath);
