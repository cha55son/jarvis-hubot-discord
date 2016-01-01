# Description:
#   Controls the space engineers server.
#
# Dependencies:
#   None
#
# Configuration:
#   SE_INSTANCE_ID The aws instance id
#   SE_EXPIRATION_SECONDS The server will expire and shut down after X seconds
#   SE_EXPIRATION_NOTIF_SECONDS Notify chat X seconds before SE_SERVER_EXPIRATION_SECONDS
#
# Commands:
#   hubot se status - Get the current status of the Space Engineers server.
#   hubot se start - Start the Space Engineers server. The server will be shutdown once the expiration period is met.
#   hubot se renew - Renews the Space Engineers server's expiration period.
#   hubot se stop - Stops the Space Engineers server.
#
# Author:
#   cha55son
Helper = require './space-engineers-helpers'

checkStatus = (inst, status, action) ->
    if (inst.State.Name != status)
        throw "**Warning!** The Space Engineers server is not #{status} therefore i'm refusing to #{action} it."
    inst # Pass inst to the next .then
warnText = '**Warning!** '

module.exports = (robot) ->
    robot.respond /se status/, (msg) ->
        Helper.getInstance().then( (inst) ->
            msg.send "The Space Engineers server is currently **#{inst.State.Name}**"
        ).catch (err) ->
            console.error err
            msg.send warnText + err

    robot.respond /se start/, (msg) ->
        Helper.getInstance().then( (inst) ->
            checkStatus inst, 'stopped', 'start'
        ).then( (inst) ->
            # Boot the server
            msg.send "Starting the Space Engineers server! Waiting on the server status..."
            Helper.startInstance().then (data) ->
                inst # Ensure inst gets sent to the next .then
        ).then( (inst) ->
            # Poll until the server is started
            Helper.pollInstance('running').then (inst) ->
                msg.send "The server was started!"
        ).catch (err) ->
            console.error err
            msg.send warnText + err

    robot.respond /se stop/, (msg) ->
        Helper.getInstance().then( (inst) ->
            checkStatus inst, 'running', 'stop'
        ).then( (inst) ->
            # Stop the server
            msg.send "Stopping the Space Engineers server! Waiting on the server status..."
            Helper.stopInstance().then (data) ->
                inst # Ensure inst gets sent to the next .then
        ).then( (inst) ->
            # Poll until the server is stopped
            Helper.pollInstance('stopped').then (inst) ->
                msg.send "The server was stopped!"
        ).catch (err) ->
            console.error err
            msg.send warnText + err

    robot.respond /se renew/, (msg) ->
        Helper.getInstance().then( (inst) ->
            checkStatus inst, 'running', 'renew'
        ).then( (inst) ->
            # renew the expiration period
            msg.send "Renewing the server!"
        ).catch (err) ->
            console.error err
            msg.send warnText + err
