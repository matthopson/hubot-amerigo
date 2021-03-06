# Description
#   Bringing teams + maps together.
#
# Configuration:
#   None
#
# Commands:
#   set location <location> - Sets your current location.
#   where is <user> - Get a user's location.
#   where is [everybody | everyone] - Get all user locations - [beta].
#   how far am I from <user> - Get your distance from another user.
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

  getStaticMap = (locations) ->
    if Array.isArray(locations)
      locationQueries = "size=800x600"

      for location in locations
        if location.hasOwnProperty('label')
          label = "label:#{location.label}%7C"
        else
          label = ''

        locationQueries += "&markers=color:red%7C#{label}#{location.latitude},#{location.longitude}"

    else
      location = locations
      locationQueries = "center=#{location.latitude},#{location.longitude}&zoom=6&size=800x600&markers=color:red%7C#{location.latitude},#{location.longitude}"

    staticMap = "https://maps.googleapis.com/maps/api/staticmap?#{locationQueries}"

    return staticMap

  # Sets a user's location
  robot.respond /(set location|i'm at|i'm in) (.*)/i, (res) ->
    rawLocation = res.match[2]

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

    if userName is 'everybody' or userName is 'everyone'
      # Do some er'body stuff
      usersQuery = []
      for index, user of robot.brain.data.users
        if user.location?
          userQuery = {
            latitude: user.location.latitude,
            longitude: user.location.longitude,
            label: user.name.charAt(0).toUpperCase()
          }
          usersQuery.push(userQuery)

      if usersQuery.length
        res.reply "Here are all the users I know about (#{usersQuery.length} total).\n" +
        getStaticMap(usersQuery)
      else
        res.reply "Sorry, I don't know about any user locations."
    else
      # Single person
      user = findUser userName
      unless user?
        res.reply "I'm sorry, I could not find this user: `@#{userName}`"
      else
        location = user.location
        if location?
          res.reply "#{userName}'s last-known location is #{location.formattedAddress}.\n" + getStaticMap(location)
        else
          res.reply "I can't find a location for this user."


  # Calculate the distance between two users
  robot.respond /(how far am I from|give me directions to) @?([\w .\-]+)\?*$/i, (res) ->
    command = res.match[1].trim().toLowerCase()
    userName = res.match[2].trim().toLowerCase()
    if userName.charAt(0) is '@'
      userName = userName.substr 1

    # Should we give directions?
    showDirections = false
    if command.indexOf('directions') > -1
      showDirections = true

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

              directions = []

              if showDirections
                route.legs[0].steps.forEach (step) ->

                  instruction = step.html_instructions
                    # Replace <b> tags with *
                    .replace(/<b>|<\/b>/g, "*")
                    # Strip the remaining HTML
                    .replace(/<[^>]*>/g, '')

                  directions.push "#{instruction} - (#{step.distance.text}/#{step.duration.text})"

              responseText = "It looks like you're about `#{distance} (#{duration})` from @#{user.name}\nHere's a link to the directions: https://www.google.com/maps/dir/#{myUser.location.latitude},#{myUser.location.longitude}/#{user.location.latitude},#{user.location.longitude}"

              if directions.length > 0
                directionsList = directions.join('\n')
                res.reply "#{responseText}\n\n#{directionsList}"
              else
                res.reply responseText
            else
              res.reply "I apologize, there was problem calculating the distance."
        else
          res.reply "I'm sorry, I can't calculate that without knowing both your locations."
