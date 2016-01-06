chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

expect = chai.expect

describe 'amerigo', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()

    require('../src/amerigo')(@robot)
