child_process = require 'child_process'
fs = require 'fs'
os = require 'os'
control = require 'control'
shell = require 'shelljs'

module.exports = patch: (cls) ->
    cls::deploy = ->
        unless @config.deployment?
            throw new RunError 'I don\'t know how to deploy your project. Create a "deployment" section in your setup file.'
        switch @config.deployment.method
            when 'galaxy'
                unless @config.deployment.server?.length
                    throw new RunError 'Sure, I can deploy to meteor.com for you, but you need to tell me the subdomain. Use the "server" keyword in your setup file.'
                # can't use shell.exec for this due to password input
                child_process.spawn 'meteor', ['deploy', @config.deployment.server], {stdio: 'inherit'}
            when 'mts', undefined
                if (@root is @config.deployment.workspace) and (fs.existsSync(@config.deployment.target)) and process.env.USER is @config.deployment.user
                    @deploy_at_server()
                else
                    controller = Object.create control.controller
                    controller.address = @config.deployment.server
                    controller.user = @config.deployment.user
                    controller.ssh "cd \"#{@config.deployment.workspace}\" && mts deploy"
            else
                throw new RunError "Unknown deployment method #{@config.deployment.method}"
    cls::deploy.is_command = true

    cls::deploy_at_server = ->
        @deployment ?= {}
        switch
            when fs.existsSync "#{@root}/.bzr"
                shell.pushd @root
                shell.exec 'bzr up'
                @deployment.revision = shell.exec('bzr revision-info').output.trim().split(' ')[1].replace '@', '-at-'
                console.log "revision: #{@deployment.revision}"
                shell.popd
                @deployment_vcs = 'bzr'
            when fs.existsSync "#{@root}/.git"
                shell.pushd @root
                shell.exec 'git pull'
                @deployment.revision = shell.exec('git rev-parse HEAD').output.trim()
                shell.popd
                @deployment_vcs = 'git'
            else
                throw new RunError 'Workspace must be a Bazaar working tree or Git repo'

        @install (err) =>
            throw err if err?

            shell.mkdir '-p', "#{@config.deployment.target}/_bundles"
            shell.pushd @root
            # not quite sure I need this, but seems to avoid problems
            shell.rm '-rf', '.meteor/local/build'
            console.log "meteor bundle #{@config.deployment.target}/_bundles/#{@deployment.revision}.tar.gz"
            # async because shelljs' docs tell us to use async for long-running
            # processes, or it uses too much cpu waiting
            shell.exec "meteor bundle #{@config.deployment.target}/_bundles/#{@deployment.revision}.tar.gz", (code, output) ->
                if code
                    throw new RunError "meteor bundle failed with error code #{code}"



                process.exit 0
