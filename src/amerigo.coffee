# Description
#   Bringing teams + maps together.
#
# Configuration:
#   None
#
# Commands:
#   #
#
# Notes:
#   None
#
# Author:
#   matthopson

module.exports = (robot) ->

  # Searches users by id or name
  findUser = (search) ->
    foundUser = null

    if typeof search is 'number'
      searchProp = 'id'
    else
      searchProp = 'name'
    for index, user of robot.brain.data.users
      if user[searchProp].toLowerCase() == search.toLowerCase()
        foundUser = user
        break

    return foundUser


  # Sets a user's location
  robot.respond /set location (.*)/i, (res) ->
    rawLocation = res.match[1]
    console.log rawLocation
    # Geocode raw location
    query = "https://maps.googleapis.com/maps/api/geocode/json?address=#{rawLocation}"
    robot.http(query)
    .get() (err, response, body) ->
      if response.statusCode is 200
        locationData = JSON.parse(body).results[0]
        location =
          query: rawLocation
          formattedAddress: locationData.formatted_address
          latitude: locationData.geometry.location.lat
          longitude: locationData.geometry.location.lng

        myUser = res.message.user
        myUser.location = location
        res.reply "Your location has been set!"
        return
      else
        res.reply "Something has gone horribly wrong."



  # Retreive location for a given user
  robot.respond /where(?:\s\w*)*?is @?([\w .\-]+)\?*$/i, (res) ->
    userName = res.match[1].trim()
    if userName.charAt(0) is '@'
      userName = userName.substr 1

    user = findUser userName
    unless user?
      res.reply "I'm sorry, I could not find this user: `@#{userName}`"
    else
      location = user.location
      if location?
        staticMap = "https://maps.googleapis.com/maps/api/staticmap?center=#{location.latitude},#{location.longitude}&zoom=6&size=800x600&markers=color:red%7C#{location.latitude},#{location.longitude}"
        res.reply "#{userName}'s last-known location is #{location.formattedAddress}.\n" + staticMap
      else
        res.reply "I can't find a location for this user."


  # Calculate the distance between two users
  robot.respond /how far am I from @?([\w .\-]+)\?*$/i, (res) ->
    userName = res.match[1].trim().toLowerCase()
    if userName.charAt(0) is '@'
      userName = userName.substr 1

    if userName == "the moon"
      res.reply "In order to give you an accurate answer, I first need to know _exactly_ how high you are... But it's probably around 239,000 miles."
    else
      user = findUser userName
      myUser = res.message.user
      unless user?
        res.reply "I'm sorry, I could not find this user: `@#{userName}`"
      else
        if user.location? and myUser.location?
          query = "https://maps.googleapis.com/maps/api/directions/json?origin=#{myUser.location.latitude},#{myUser.location.longitude}&destination=#{user.location.latitude},#{user.location.longitude}"
          robot.http(query)
          .get() (err, response, body) ->
            if response.statusCode is 200
              route = JSON.parse(body).routes[0]

              distance = route.legs[0].distance.text
              duration = route.legs[0].duration.text

              res.reply "It looks like you're about `#{distance} (#{duration})` from @#{user.name}"
            else
              res.reply "I apologize, there was problem calculating the distance."
        else
          res.reply "I'm sorry, I can't calculate that without knowing both your locations."
