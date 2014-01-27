child_process = require 'child_process'
os = require 'os'
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
                throw new RunError 'Sorry, deployment with server-side mts not yet implemented.'
            else
                throw new RunError "Unknown deployment method #{@config.deployment.method}"
    cls::deploy.is_command = true
