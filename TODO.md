# TODO

The main goal is to prevent recompilation wasting ~20seconds every F5 hit.
Additionally I'll try to integrate few tweaks making workflow less shameful in 2016.

## Changes

1. ~~Add [gulp-sass-graph](https://www.npmjs.com/package/gulp-sass-graph)~~
1. Add livereload if it might work with ASP.NET
1. Accept --force or add 'clean' task
1. Add *.csproj with configuration
1. Add gulp-notify to inform about compilation errors

## Tests

1. ~~Automatic test of caching~~
    ~~Add commands to prove execution times are lower~~
1. ~~Automatic test to verify watch still works~~
1. Automatic test to measure watch delay
1. Automatic test by calling msbuild

## Trial and learn

1. [gulp-sass-partials-imported](https://github.com/G100g/gulp-sass-partials-imported)
1. [gulp-sourcemaps](https://github.com/altmind/gulp-sass)
