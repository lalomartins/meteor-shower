child_process = require 'child_process'
fs = require 'fs'
os = require 'os'
control = require 'control'
pidlock = require 'pidlock'
shell = require 'shelljs'

module.exports = patch: (cls) ->
    cls::deploy = ->
        unless @config.deployment?
            throw new RunError 'I don\'t know how to deploy your project. Create a "deployment" section in your setup file.'
        switch @config.deployment.method
            when 'galaxy'
                unless @config.deployment.server?.length
                    throw new RunError 'Sure, I can deploy to meteor.com for you, but you need to tell me the subdomain. Use the "server" keyword in your setup file.'
                args = ['deploy', @config.deployment.server]
                if @config?.deployment?.settings?.length
                    args.push '--settings'
                    args.push "#{@root}/#{@config.deployment.settings}"
                # can't use shell.exec for this due to password input
                child_process.spawn 'meteor', args, {stdio: 'inherit'}
            when 'mts', undefined
                if (@root is @config.deployment.workspace) and (fs.existsSync(@config.deployment.target)) and process.env.USER is @config.deployment.user
                    pidlock.guard @config.deployment.target, '_deploying.lock', (error, data, cleanup) =>
                        if error?
                            throw new RunError 'A deployment is already in progress.'
                        process.on 'exit', =>
                            cleanup()
                            shell.rm '-rf', "#{@config.deployment.target}/deploying.lock"
                        @deploy_at_server()
                else
                    controller = Object.create control.controller
                    controller.address = @config.deployment.server
                    controller.user = @config.deployment.user
                    # agent forwarding is probably needed to talk to bzr+ssh
                    # or github or load balancer etc
                    controller.sshOptions = ['-A']
                    controller.ssh "cd \"#{@config.deployment.workspace}\" && mts deploy"
            else
                throw new RunError "Unknown deployment method #{@config.deployment.method}"
    cls::deploy.is_command = true

    cls::get_deployment_instance = ->
        switch @config.deployment.instances?.length
            when undefined
                'run'
            when 1
                @config.deployment.instances[0]
            when 2
                switch
                    when fs.existsSync "#{@config.deployment.target}/live"
                        live = fs.readlinkSync "#{@config.deployment.target}/live"
                        if @config.deployment.instances[0] is live
                            @config.deployment.instances[1]
                        else
                            @config.deployment.instances[0]
                    when fs.existsSync "#{@config.deployment.target}/preview"
                        # not that sure about this… if there's no live ATM,
                        # maybe better to deploy to the other one?
                        fs.readlinkSync "#{@config.deployment.target}/preview"
                    else
                        @config.deployment.instances[0]
            else
                throw new RunError 'Multi-instance deployment not yet implemented'

    cls::get_deployment_state = ->
        # MAYBE: redefine get_deployment_instance() in terms of this
        unless @config.deployment? and (@config.deployment.method is 'mts' or @config.deployment.method is undefined)
            throw new RunError 'Meteor Shower isn\'t managing this deployment'
        instances = {}
        switch @config.deployment.instances?.length
            when undefined
                instances.live =
                    name: 'run'
            when 1
                instances.live =
                    name: @config.deployment.instances[0]
            when 2
                if fs.existsSync "#{@config.deployment.target}/live"
                    instances.live =
                        name: fs.readlinkSync "#{@config.deployment.target}/live"
                if fs.existsSync "#{@config.deployment.target}/preview"
                    instances.preview =
                        name: fs.readlinkSync "#{@config.deployment.target}/preview"
            else
                throw new RunError 'Multi-instance deployment not yet implemented'
        for role, info of instances
            continue unless info?
            info.tree_path = fs.readlinkSync "#{@config.deployment.target}/#{info.name}"
            info.revision = info.tree_path.replace(/^_tree\//, '').replace(/-at-/, '@')
            stats = fs.statSync "#{@config.deployment.target}/#{info.tree_path}"
            info.deploy_date = stats.ctime
        instances

    cls::deploy_at_server = ->
        @deployment ?= {}
        @deployment.instance ?= @get_deployment_instance()
        switch
            when fs.existsSync "#{@root}/.bzr"
                shell.pushd @root
                shell.exec 'bzr up'
                @deployment.revision = shell.exec('bzr revision-info', silent: true).output.trim().split(' ')[1].replace '@', '-at-'
                console.log "deploying revision: #{@deployment.revision}"
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

        @install_dependencies (err) =>
            console.debug 'done with install'
            throw err if err?

            shell.mkdir '-p', "#{@config.deployment.target}/_bundles"
            shell.pushd @root
            # not quite sure I need this, but seems to avoid problems
            shell.rm '-rf', '.meteor/local/build'
            console.log "meteor bundle #{@config.deployment.target}/_bundles/#{@deployment.revision}.tar.gz"
            # async because shelljs' docs tell us to use async for long-running
            # processes, or it uses too much cpu waiting
            shell.exec "meteor bundle #{@config.deployment.target}/_bundles/#{@deployment.revision}.tar.gz", (code, output) =>
                shell.popd()
                if code
                    throw new RunError "meteor bundle failed with error code #{code}"

                shell.mkdir '-p', "#{@config.deployment.target}/_tree/#{@deployment.revision}"
                shell.pushd "#{@config.deployment.target}"
                shell.exec "tar -C _tree/#{@deployment.revision} --strip-components=1 -xf _bundles/#{@deployment.revision}.tar.gz"
                # shelljs master has ln, but no release yet does
                # shell.ln '-fs', "_tree/#{@deployment.revision}", @deployment.instance
                if @config.deployment.instance_control?.stop?
                    console.log @config.deployment.instance_control.stop.replace /\$\{instance\}/g, @deployment.instance
                    shell.exec @config.deployment.instance_control.stop.replace /\$\{instance\}/g, @deployment.instance
                shell.exec "ln -fsT _tree/#{@deployment.revision} #{@deployment.instance}"
                if @config.deployment.instance_control?.start?
                    console.log @config.deployment.instance_control.start.replace /\$\{instance\}/g, @deployment.instance
                    shell.exec @config.deployment.instance_control.start.replace /\$\{instance\}/g, @deployment.instance
                if @config.deployment.instances?.length
                    shell.exec "ln -fsT #{@deployment.instance} preview"

                @clean_at_server()
                process.exit 0


    ########## Clean
    cls::clean = ->
        unless @config.deployment?
            throw new RunError 'I don\'t know how to deploy your project. Create a "deployment" section in your setup file.'
        switch @config.deployment.method
            when 'galaxy'
                console.log "Sorry, clean makes no sense with galaxy deployment"
            when 'mts', undefined
                if (@root is @config.deployment.workspace) and (fs.existsSync(@config.deployment.target)) and process.env.USER is @config.deployment.user
                    pidlock.guard @config.deployment.target, '_deploying.lock', (error, data, cleanup) =>
                        if error?
                            throw new RunError 'A deployment is currently in progress.'
                        process.on 'exit', =>
                            cleanup()
                            shell.rm '-rf', "#{@config.deployment.target}/deploying.lock"
                        @clean_at_server()
                else
                    controller = Object.create control.controller
                    controller.address = @config.deployment.server
                    controller.user = @config.deployment.user
                    # hack, but it's ATM the only way to shut control up
                    controller.logBuffer = (prefix, buffer) ->
                        if prefix is 'stdout: '
                            process.stdout.write buffer
                        else
                            control.controller.logBuffer.call controller, prefix, buffer
                    # controller.stdout.on 'data', (chunk) ->
                    #     process.stdout.write chunk
                    controller.ssh "cd \"#{@config.deployment.workspace}\" && mts clean"
            else
                throw new RunError "Unknown deployment method #{@config.deployment.method}"
    cls::clean.is_command = true

    cls::clean_at_server = ->
        in_use = []
        for name in fs.readdirSync @config.deployment.target
            try
                target = fs.readlinkSync "#{@config.deployment.target}/#{name}"
            catch error
                continue if error.code is 'EINVAL'
                throw error
            if match = target.match /^_tree\/([^\/]+)/
                in_use.push match[1]
        for name in fs.readdirSync "#{@config.deployment.target}/_tree"
            unless name in in_use
                shell.rm '-rf', "#{@config.deployment.target}/_tree/#{name}"


    ########## Status
    cls::status = ->
        unless @config.deployment?
            throw new RunError 'I don\'t know how to deploy your project. Create a "deployment" section in your setup file.'
        switch @config.deployment.method
            when 'galaxy'
                console.log "Deploying with galaxy to #{config.deployment.server}"
            when 'mts', undefined
                if (@root is @config.deployment.workspace) and (fs.existsSync(@config.deployment.target)) and process.env.USER is @config.deployment.user
                    pidlock.guard @config.deployment.target, '_deploying.lock', (error, data, cleanup) =>
                        if error?
                            throw new RunError 'A deployment is currently in progress.'
                        process.on 'exit', =>
                            cleanup()
                            shell.rm '-rf', "#{@config.deployment.target}/deploying.lock"
                        @status_at_server()
                else
                    controller = Object.create control.controller
                    controller.address = @config.deployment.server
                    controller.user = @config.deployment.user
                    # hack, but it's ATM the only way to shut control up
                    controller.logBuffer = (prefix, buffer) ->
                        if prefix is 'stdout: '
                            process.stdout.write buffer
                        else
                            control.controller.logBuffer.call controller, prefix, buffer
                    # controller.stdout.on 'data', (chunk) ->
                    #     process.stdout.write chunk
                    controller.ssh "cd \"#{@config.deployment.workspace}\" && mts status"
            else
                throw new RunError "Unknown deployment method #{@config.deployment.method}"
    cls::status.is_command = true

    cls::status_at_server = ->
        state = @get_deployment_state()
        if Object.keys(state).length is 0
            console.log 'No deployments found'
        else
            for role, info of state
                console.log """
                current #{role}: #{info.name}
                    revision: #{info.revision}
                    deployed: #{info.deploy_date}"""
