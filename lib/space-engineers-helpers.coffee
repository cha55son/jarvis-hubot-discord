# This script provides helper functions to space-engineers.coffee

Promise = require 'promise'
AWS = require 'aws-sdk'
if (
    !process.env.AWS_REGION ||
    !process.env.AWS_ACCESS_KEY_ID ||
    !process.env.AWS_SECRET_ACCESS_KEY ||
    !process.env.SE_INSTANCE_ID
)
    throw "Ensure all environment variables are set for the space-engineers.coffee script"
    

AWS.config.update
    region: process.env.AWS_REGION,
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
SE_INST_ID = process.env.SE_INSTANCE_ID
SE_EXP_SEC = parseInt(process.env.SE_EXPIRATION_SECONDS || 7200)
SE_EXP_SEC_NOTIF = parseInt(process.env.SE_EXPIRATION_NOTIF_SECONDS || 600)
POLL_TIMEOUT_SECONDS = 300
SE_BRAIN_KEY = 'se.serverExpiration'
ROBOT = null
EC2 = new AWS.EC2()

getInstance = ->
    ROBOT.logger.debug "se.getInstance"
    return new Promise (resolve, reject) ->
        EC2.describeInstances
            InstanceIds: [SE_INST_ID]
        , (err, data) ->
            if err
                return reject(err.message)
            if data.Reservations && data.Reservations.length != 1
                return reject "There were no reservations for instance id: #{SE_INST_ID}."
            res = data.Reservations[0]
            if res.Instances && res.Instances.length != 1
                return reject "There were no instances for reservation id: #{res.ReservationId}, " +
                            "instance id: #{SE_INST_ID}."
            inst = res.Instances[0]
            if inst.InstanceId != SE_INST_ID
                return reject "Invalid instance id found. Reservation id: #{res.ReservationId}, " +
                            "instance id: #{inst.InstanceId}."
            resolve inst

stopInstance = ->
    ROBOT.logger.debug "se.stopInstance"
    return new Promise (resolve, reject) ->
        EC2.stopInstances { InstanceIds: [SE_INST_ID] }, (err, data) ->
            return reject(err.message) if err
            ROBOT.brain.set SE_BRAIN_KEY, { timestamp: null, room: null }
            resolve(data)

pollInstance = (expectedStatus) ->
    ROBOT.logger.debug "se.pollInstance"
    return new Promise (resolve, reject) ->
        timeout = POLL_TIMEOUT_SECONDS
        startPoll = ->
            setTimeout ->
                if timeout == 0
                    return reject "The server took longer than #{POLL_TIMEOUT_SECONDS}s " +
                                    "to reach the #{expectedStatus} status."
                timeout -= 1
                getInstance().then (inst) ->
                    ROBOT.logger.debug "Polling #{timeout}: Found status '#{inst.State.Name}'."
                    if inst.State.Name == expectedStatus
                        return resolve inst
                    # Didn't have the status we wanted. Run another poll.
                    startPoll()
                .catch (err) ->
                    reject err
            , 1000
        startPoll()

brainPoll = ->
    interval = 5
    setTimeout ->
        ROBOT.logger.debug "se.brainPoll"
        data = ROBOT.brain.get SE_BRAIN_KEY
        curTimestamp = Math.floor(Date.now() / 1000)
        notifTimestamp = data.timestamp - SE_EXP_SEC_NOTIF
        # If the value is invalid run another poll
        if !data.timestamp
            ROBOT.logger.debug "se.brainPoll: Invalid timestamp, skipping."
            brainPoll()
        # Are we near the notification period?
        # If so, send a notification to the room.
        else if (notifTimestamp - interval/2) < curTimestamp && curTimestamp < (notifTimestamp + interval/2)
            ROBOT.logger.debug "se.brainPoll: Sending the notification that the server will be shutting down soon."
            ROBOT.logger.debug "se.brainPoll: Current timestamp #{curTimestamp}."
            ROBOT.logger.debug "se.brainPoll: Notification timestamp #{notifTimestamp}."
            ROBOT.logger.debug "se.brainPoll: Expiration timestamp #{data.timestamp}."
            ROBOT.messageRoom data.room, "**Warning!** The Space Engineers server will " +
                                         "shutdown in #{(data.timestamp - curTimestamp) / 60} minutes."
            ROBOT.messageRoom data.room, "Run `#{ROBOT.name} se renew` to reset the expiration."
            brainPoll()
        # Are we past the date already? If so check the server
        # and kill it if it is running.
        else if curTimestamp > data.timestamp
            ROBOT.logger.debug "se.brainPoll: Shutting down an expired server."
            getInstance().then (inst) ->
                if ['stopping', 'stopped'].indexOf(inst.State.Name) != -1
                    ROBOT.logger.debug "se.brainPoll: Found a 'stopping' status, resetting the brain data."
                    ROBOT.brain.set SE_BRAIN_KEY, { timestamp: null, room: null }
                    brainPoll()
                    return
                # Check for 'running' in case it's in between states
                ROBOT.logger.info "Found server running after expiration date. Shutting down."
                ROBOT.messageRoom data.room, "Stopping the Space Engineers server! Waiting on the server status..."
                stopInstance().then (inst) ->
                    # Poll until the server is stopped
                    pollInstance('stopped').then (inst) ->
                        ROBOT.messageRoom data.room, "The Space Engineers server is stopped!"
            .then ->
                brainPoll()
            .catch (err) ->
                console.error err
                ROBOT.messageRoom data.room, warnText + "There was an error querying the " +
                                                        "Space Engineers server."
                brainPoll()
        else
            brainPoll()
    , interval * 1000

module.exports = (robot) ->
    ROBOT = robot
    # Ensure the brain data is correct
    data = robot.brain.get SE_BRAIN_KEY
    if !data || !data.timestamp || !data.room
        data = { timestamp: null, room: null }
    robot.brain.set SE_BRAIN_KEY, data
    # Monitor the SE_BRAIN_KEY and stop any servers if needed
    brainPoll()

    # Return the useful functions
    getInstance: getInstance
    startInstance: ->
        ROBOT.logger.debug "se.startInstance"
        return new Promise (resolve, reject) ->
            EC2.startInstances { InstanceIds: [SE_INST_ID] }, (err, data) ->
                return reject(err.message) if err
                resolve(data)
    stopInstance: stopInstance
    renewInstance: (roomName) ->
        ROBOT.logger.debug "se.renewInstance"
        robot.brain.set SE_BRAIN_KEY,
            timestamp: (Math.floor(Date.now() / 1000) + SE_EXP_SEC)
            room: roomName
    pollInstance: pollInstance
