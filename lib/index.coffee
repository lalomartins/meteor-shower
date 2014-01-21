fs = require 'fs'
shell = require 'shelljs'
yaml = require 'yamljs'

class MeteorApp
    constructor: (@root) ->
        console.log "Meteor app at #{@root}"
        yamlfile = switch
            when fs.existsSync 'setup.yaml'
                'setup.yaml'
            when fs.existsSync '.setup.yaml'
                '.setup.yaml'
            when fs.existsSync '.meteor/setup.yaml'
                '.meteor/setup.yaml'
            else
                throw new Error 'no setup.yaml found'
        @config = yaml.load yamlfile

    install: ->
        console.log @config

    run: ->
        @install()
        shell.exec 'meteor'

module.exports =
    MeteorApp: MeteorApp
    main: ->
        meteor_dir = switch
            when fs.existsSync '.meteor'
                process.cwd()
            when fs.existsSync 'app/.meteor'
                "#{process.cwd()}/app"
            else
                throw new Error 'No Meteor app found'
        app = new MeteorApp meteor_dir
        # TODO: parse commands
        app.run()
