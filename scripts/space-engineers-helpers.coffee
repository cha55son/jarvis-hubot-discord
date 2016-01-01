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
EC2 = new AWS.EC2()

getInstance = ->
    return new Promise (resolve, reject) ->
        EC2.describeInstances
            InstanceIds: [SE_INST_ID]
        , (err, data) ->
            return reject(err.message) if (err)
            if (data.Reservations && data.Reservations.length != 1)
                return reject "There were no reservations for instance id: #{SE_INST_ID}."
            res = data.Reservations[0]
            if (res.Instances && res.Instances.length != 1)
                return reject "There were no instances for reservation id: #{res.ReservationId}, " +
                            "instance id: #{SE_INST_ID}."
            inst = res.Instances[0]
            if (inst.InstanceId != SE_INST_ID)
                return reject "Invalid instance id found. Reservation id: #{res.ReservationId}, " +
                            "instance id: #{inst.InstanceId}."
            resolve inst

module.exports =
    getInstance: getInstance
    startInstance: ->
        return new Promise (resolve, reject) ->
            EC2.startInstances { InstanceIds: [SE_INST_ID] }, (err, data) ->
                return reject(err.message) if (err)
                resolve(data)

    stopInstance: ->
        return new Promise (resolve, reject) ->
            EC2.stopInstances { InstanceIds: [SE_INST_ID] }, (err, data) ->
                return reject(err.message) if (err)
                resolve(data)

    renewInstance: ->

    pollInstance: (expectedStatus) ->
        return new Promise (resolve, reject) ->
            timeout = POLL_TIMEOUT_SECONDS
            startPoll = ->
                setTimeout( ->
                    if (timeout == 0)
                        return reject "The server took longer than #{POLL_TIMEOUT_SECONDS}s " +
                                    "to reach the #{expectedStatus} status."
                    timeout -= 1
                    getInstance().then( (inst) ->
                        if (inst.State.Name == expectedStatus)
                            return resolve inst
                        # Didn't have the status we wanted. Run another poll.
                        startPoll()
                    ).catch (err) ->
                        reject err
                , 1000)
            startPoll()
