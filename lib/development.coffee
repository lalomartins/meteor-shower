fs = require 'fs'
os = require 'os'
shell = require 'shelljs'

replace_vars = (vars, text) ->
    switch typeof text
        when 'string'
            r = text
        when 'object'
            r = JSON.stringify text
        when 'undefined'
            return
        else
            return "#{text}"
    for name, value of vars
        r = r.replace (new RegExp "\\$\\{#{name}\\}", 'g'), value
    r

module.exports = patch: (cls) ->
    cls::run = ->
        @install_dependencies (err) =>
            throw err if err?
            shell.pushd @root
            if @config?.development?.environment?
                vars =
                    APP_ROOT: @root
                for name, addresses of os.networkInterfaces()
                    for address in addresses
                        if address.internal is false
                            if address.family is 'IPv4' and not vars.PUBLIC_IPV4?
                                vars.PUBLIC_IPV4 = address.address
                            if address.family is 'IPv6' and not vars.PUBLIC_IPV6?
                                vars.PUBLIC_IPV6 = address.address
                        break if vars.PUBLIC_IPV4? and vars.PUBLIC_IPV6?
                    break if vars.PUBLIC_IPV4? and vars.PUBLIC_IPV6?
                for name, value of @config.development.environment
                    shell.env[name] = replace_vars vars, value
            meteor_cmdline = switch
                when @config?.development?.settings?.length
                    "meteor --settings #{@root}/#{@config.development.settings}"
                when fs.existsSync "#{@root}/.meteor/settings.json"
                    "meteor --settings #{@root}/.meteor/settings.json"
                else
                    'meteor'
            shell.exec meteor_cmdline, async: true
            shell.popd
    cls::run.is_command = true
