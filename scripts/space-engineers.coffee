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


module.exports = (robot) ->
    robot.respond /.*/, (msg) ->
        msg.send "Message received! Sorry, but i'm currently under construction."
