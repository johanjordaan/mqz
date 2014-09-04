// Simple shim directly into the Gruntfile.ls version
require('LiveScript');

module.exports = function (grunt) {
    require('./gruntfile.ls')(grunt);
}
