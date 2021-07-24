/**
 * an example gulpfile to make ant-less existdb package builds a reality
 */
const { src, dest, watch, series, parallel, lastRun } = require('gulp')
const { createClient } = require('@existdb/gulp-exist')
const zip = require("gulp-zip")
const replace = require('@existdb/gulp-replace-tmpl')
const rename = require('gulp-rename')
const del = require('delete')

// read metadata from package.json and .existdb.json
const { version, license, author } = require('./package.json')
const { package, servers } = require('./.existdb.json')
 
// .tmpl replacements to include 
// first value wins
const replacements = [package, {version, license, author}]
const serverInfo = servers.localhost
const { port, hostname } = new URL(serverInfo.server)
const connectionOptions = {
    basic_auth: {
        user: serverInfo.user, 
        pass: serverInfo.password
    },
    host: hostname,
    port
}

const existClient = createClient(connectionOptions);

/**
 * Use the `delete` module directly, instead of using gulp-rimraf
 */
function clean (cb) {
    del(['build'], cb);
}
exports.clean = clean

/**
 * replace placeholders 
 * in src/repo.xml.tmpl and 
 * output to build/repo.xml
 */
function templates () {
  return src('src/*.tmpl')
    .pipe(replace(replacements))
    .pipe(rename(path => { path.extname = "" }))
    .pipe(dest('build/'))
}
exports.templates = templates

function watchTemplates () {
    watch('src/*.tmpl', series(templates))
}
exports["watch:tmpl"] = watchTemplates

const static = 'src/**/*.{xml,html,xq,xquery,xql,xqm,xsl,xconf,svg,png}'

/**
 * copy html templates, XSL stylesheet, XMLs and XQueries to 'build'
 */
function copyStatic () {
    return src(static).pipe(dest('build'))
}
exports.copy = copyStatic

function watchStatic () {
    watch(static, series(copyStatic));
}
exports["watch:static"] = watchStatic

/**
 * Upload all files in the build folder to existdb.
 * This function will only upload what was changed 
 * since the last run (see gulp documentation for lastRun).
 */
function deploy () {
    return src('build/**/*', {
            base: 'build',
            since: lastRun(deploy) 
        })
        .pipe(existClient.dest({target: serverInfo.root}))
}

function watchBuild () {
    watch('build/**/*', series(deploy))
}

// construct the current xar name from available data
const packageName = () => `${package.target}-${version}.xar`

/**
 * create XAR package in repo root
 */
function xar () {
    return src('build/**/*', {base: 'build'})
        .pipe(zip(packageName()))
        .pipe(dest('.'))
}

/**
 * upload and install the latest built XAR
 */
function installXar () {
    return src(packageName())
        .pipe(existClient.install())
}

// composed tasks
const build = series(
    clean,
    templates,
    copyStatic
)
const watchAll = parallel(
    watchStatic,
    watchTemplates,
    watchBuild
)

exports.build = build
exports.watch = watchAll

exports.deploy = series(build, deploy)
exports.xar = series(build, xar)
exports.install = series(build, xar, installXar)

// main task for day to day development
exports.default = series(build, deploy, watchAll)
