_ = require 'prelude-ls'
module.exports = (grunt) ->
  grunt.initConfig do
    pkg: grunt.file.readJSON 'package.json'

    uglify:
      options:
        banner: '/*! <%= pkg.name %> <%= grunt.template.today("yyyy-mm-dd") %> */\n'
      build:
        src: 'src/<%= pkg.name %>.js'
        dest: 'build/<%= pkg.name %>.min.js'

    deadscript:
      build:
        expand: true,
        cwd: './src',
        src: ['**/*.ls'],
        dest: './dist',
        ext: '.js'
        extDot : 'last'

    watch:
      serverSourceChanges:
        files:
           'src/*.ls'
        tasks: ['deadscript' 'mochaTest:test']
      frontEndChanges:
        files:
           'src/client/*.ls'
           'src/client/*.html'
           'src/client/*.less'
           'src/client/images/*.png'
        tasks: ['deadscript' 'copy:frontEndStatic' 'less:all' 'mochaTest:test']
      testChanges:
        files:
           'src/test/*.ls'
        tasks: ['deadscript' 'mochaTest:test']


    concurrent:
      apiAndAdmin:
        tasks: ['watch:frontEndChanges' 'watch:serverSourceChanges' 'nodemon:adminServer' 'nodemon:apiServer']
        options:
           logConcurrentOutput: true
      api:
        tasks: ['watch:frontEndChanges' 'watch:serverSourceChanges' 'nodemon:apiServer']
        options:
           logConcurrentOutput: true
      admin:
        tasks: ['watch:frontEndChanges' 'watch:serverSourceChanges' 'nodemon:adminServer']
        options:
           logConcurrentOutput: true
      tests:
        tasks: ['watch:frontEndChanges' 'watch:serverSourceChanges' 'watch:testChanges' ]
        options:
           logConcurrentOutput: true

    nodemon:
      adminServer:
        script: 'dist/admin_server.js'
        options:
           pwd: 'dist'
      apiServer:
        script: 'dist/api_server.js'
        options:
           pwd: 'dist'

    copy:
      frontEndStatic:
        files: [
         * expand: true
           cwd: 'src/client/'
           src: ['*.html']
           dest: 'dist/client/'
         * expand: true
           cwd: 'src/client/images'
           src: ['*.png']
           dest: 'dist/client/images'
         * expand: true
           cwd: 'src/client/'
           src: ['libs/**']
           dest: 'dist/client/'
        ]

    bowercopy:
      options:
        srcPrefix: 'bower_components'
      scripts:
        options:
           destPrefix: 'dist/client/libs'
        files:
           'angular/angular.js': 'angular/angular.js'
           'angular/angular-route.js': 'angular-route/angular-route.js'
           'angular/angular-resource.js': 'angular-resource/angular-resource.js'
           'prelude-browser.js': 'prelude-ls/browser/prelude-browser.js'

    forever:
      adminServer:
        options:
           index: 'dist/admin_server.js'
           logDir: 'logs/'
      apiServer:
        options:
           index: 'dist/api_server.js'
           logDir: 'logs/'

    mochaTest:
      test:
        options:
          reporter: 'dot'
        src: ['./dist/test/**/*.js']

      coverage:
        options:
          reporter: 'dot'
        src: ['./coverage/instrument/dist/test/**/*.js']


    instrument:
      files: 'dist/**/*.js'
      options:
        lazy: true
        basePath: './coverage/instrument/'
    storeCoverage:
      options:
        dir: './coverage/reports'
    makeReport:
      src: './coverage/reports/**/*.json',
      options:
        type: 'lcov',
        dir: './coverage/reports',
        print: 'detail'

    less:
      all:
        files: [
          expand: true
          cwd:'src/'
          src: ['**/*.less']
          dest: './dist/'
          ext:'.css'
        ]

    jsdoc:
      docstrap:
        src: ['./dist/utils.js'] #, './README.md']
        options:
          destination : './dist/client/doc/'
          template : "node_modules/ink-docstrap/template"
          configure : "node_modules/ink-docstrap/template/jsdoc.conf.json"

  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-concurrent'
  grunt.loadNpmTasks 'grunt-nodemon'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-bowercopy'
  grunt.loadNpmTasks 'grunt-forever'
  grunt.loadNpmTasks 'grunt-mocha-test'
  grunt.loadNpmTasks 'grunt-deadscript'
  grunt.loadNpmTasks 'grunt-istanbul'
  grunt.loadNpmTasks 'grunt-contrib-less'
  grunt.loadNpmTasks 'grunt-jsdoc'


  grunt.registerTask 'devmon',  ['concurrent:apiAndAdmin']
  grunt.registerTask 'apimon',  ['concurrent:api']
  grunt.registerTask 'adminmon',['concurrent:admin']
  grunt.registerTask 'test',    ['concurrent:tests']
  grunt.registerTask 'default', ['deadscript' 'less:all' 'copy:frontEndStatic' 'bowercopy']

  grunt.registerTask 'docs', ['deadscript' 'jsdoc']



  grunt.registerTask 'coverage', ['deadscript','instrument', 'mochaTest:coverage',
    'storeCoverage', 'makeReport']
