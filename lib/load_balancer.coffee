child_process = require 'child_process'
fs = require 'fs'
os = require 'os'
path = require 'path'
control = require 'control'
pidlock = require 'pidlock'
shell = require 'shelljs'

module.exports = patch: (cls) ->
    cls::release = ->
        unless @config.deployment?
            throw new RunError 'I don\'t know how to release your project. Create a "deployment" section in your setup file.'
        switch @config.deployment.method
            when 'galaxy'
                throw new RunError 'It doesn\'t make sense to use this command with galaxy deployment.'
            when 'mts', undefined
                if (@config.deployment.instances?.length ? 0) < 2
                    throw new RunError 'It doesn\'t make sense to use this command with less than two instances.'
                if (@root is @config.deployment.workspace) and (fs.existsSync(@config.deployment.target)) and process.env.USER is @config.deployment.user
                    pidlock.guard @config.deployment.target, '_deploying.lock', (error, data, cleanup) =>
                        if error?
                            throw new RunError 'A deployment is already in progress.'
                        process.on 'exit', =>
                            cleanup()
                            shell.rm '-rf', "#{@config.deployment.target}/deploying.lock"
                        @release_at_server()
                else
                    controller = Object.create control.controller
                    controller.address = @config.deployment.server
                    controller.user = @config.deployment.user
                    controller.sshOptions = ['-A']
                    controller.ssh "cd \"#{@config.deployment.workspace}\" && mts release"
            else
                throw new RunError "Unknown deployment method #{@config.deployment.method}"
    cls::release.is_command = true

    cls::release_at_server = ->
        state = @get_deployment_state()
        unless state.preview?.name?
            throw new RunError 'No preview instance found, nothing to release'

        shell.pushd @config.deployment.target
        new_live = state.preview.name
        if @config.deployment.instances.length is 2
            if state.live?
                new_preview = state.live.name
            else
                for instance in @config.deployment.instances
                    if instance isnt new_live
                        new_preview = instance
                        break
            shell.exec "ln -fsT #{new_preview} preview"
        else
            new_preview = state.preview.name
            if @config.deployment.instance_control?.stop?
                finished = =>
                    console.log @config.deployment.instance_control.stop.replace /\$\{instance\}/g, state.live.name
                    shell.exec @config.deployment.instance_control.stop.replace /\$\{instance\}/g, state.live.name
        shell.exec "ln -fsT #{new_live} live"
        shell.popd

        lb_config = @config.deployment.load_balancer
        if lb_config?
            lb_config.base_address ?= @config.deployment.server
            lb_config.base_port ?= 3000
            lb_config.name ?= path.basename @config.deployment.workspace

            for name, index in @config.deployment.instances
                if name is new_live
                    live_port = Number(lb_config.base_port) + 10 * index
                if name is new_preview
                    preview_port = Number(lb_config.base_port) + 10 * index

            upstreams = """
            upstream #{lb_config.name}-live {
                # running instance: #{new_live}
                server #{lb_config.base_address}:#{live_port};
            }
            upstream #{lb_config.name}-preview {
                # running instance: #{new_preview}
                server #{lb_config.base_address}:#{preview_port};
            }
            """

            if @config.deployment.load_balancer.server?
                controller = Object.create control.controller
                controller.address = @config.deployment.load_balancer.server
                controller.user = @config.deployment.load_balancer.user ? @config.deployment.user
                upstreams.to "#{@config.deployment.target}/.mts-upstreams.tmp"
                controller.scp "#{@config.deployment.target}/.mts-upstreams.tmp", @config.deployment.load_balancer.file, =>
                    shell.rm "#{@config.deployment.target}/.mts-upstreams.tmp"
                    controller.ssh 'sudo nginx -t && sudo nginx -s reload', finished

            else
                upstreams.to @config.deployment.load_balancer.file
                shell.exec 'sudo nginx -t && sudo nginx -s reload'
                finished?()
