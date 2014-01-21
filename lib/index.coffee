fs = require 'fs'
shell = require 'shelljs'
yaml = require 'yamljs'

class RunError extends Error
    # no idea why it won't pass on the message if I define it as
    # constructor: -> super
    constructor: (@message) -> super
    exit_code: 1

class MeteorApp
    constructor: (@root, extra_conf_path) ->
        console.log "Meteor app at #{@root}"
        yamlfile = switch
            when fs.existsSync "#{@root}/setup.yaml"
                "#{@root}/setup.yaml"
            when fs.existsSync "#{@root}/.setup.yaml"
                "#{@root}/.setup.yaml"
            when fs.existsSync "#{@root}/.meteor/setup.yaml"
                "#{@root}/.meteor/setup.yaml"
            when extra_conf_path?
                for extra_conf_dir in extra_conf_path
                    console.log "also searching for config in #{extra_conf_dir}"
                    switch
                        when fs.existsSync "#{extra_conf_dir}/setup.yaml"
                            found = "#{extra_conf_dir}/setup.yaml"
                            break
                        when fs.existsSync "#{extra_conf_dir}/.setup.yaml"
                            found = "#{extra_conf_dir}/.setup.yaml"
                            break
                unless found?
                    throw new RunError 'no setup.yaml found'
                found
            else
                throw new RunError 'no setup.yaml found'
        @config = yaml.load yamlfile

    install: ->
        return unless @config.packages?
        for package_name, options of @config.packages
            if fs.existsSync "#{@root}/packages/#{package_name}"
                console.log "#{package_name} already installed; updating not yet implemented"
            else
                switch options.from
                    when 'git'
                        unless shell.which 'git'
                            throw new RunError 'You don\'t seem to have git in your system. Please install it.'
                        console.log "installing #{package_name} from git: #{options.remote}"
                        shell.exec "git clone --recursive #{options.remote} #{@root}/packages/#{package_name}"
                    when 'bzr', 'archive', 'atmosphere'
                        console.log "Sorry, installing from #{options.from} not yet implemented"
                    else
                        throw new RunError "Unknown installation method #{options.from}"

    run: ->
        @install()
        shell.pushd @root
        shell.exec 'meteor'
        shell.popd

module.exports =
    MeteorApp: MeteorApp
    RunError: RunError
    main: ->
        try
            meteor_dir = switch
                when fs.existsSync '.meteor'
                    process.cwd()
                when fs.existsSync 'app/.meteor'
                    extra_conf_path = [process.cwd()]
                    "#{process.cwd()}/app"
                else
                    throw new RunError 'No Meteor app found'
            app = new MeteorApp meteor_dir, extra_conf_path
            # TODO: parse commands
            app.run()
        catch e
            if e instanceof RunError
                console.error e.message
                process.exit e.exit_code
            else
                throw e
