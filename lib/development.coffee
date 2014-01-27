os = require 'os'
shell = require 'shelljs'

replace_vars = (vars, text) ->
    r = text
    for name, value of vars
        r = r.replace (new RegExp "\\$\\{#{name}\\}", 'g'), value
    r

module.exports = patch: (cls) ->
    cls::run = ->
        @install (err) =>
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
            shell.exec 'meteor'
            shell.popd
    cls::run.is_command = true
