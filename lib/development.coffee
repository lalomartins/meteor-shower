shell = require 'shelljs'

module.exports = patch: (cls) ->
    cls::run = ->
        @install()
        shell.pushd @root
        if @config?.development?.environment?
            for name, value of @config.development.environment
                shell.env[name] = value
        shell.exec 'meteor'
        shell.popd
