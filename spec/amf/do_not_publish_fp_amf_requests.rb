require File.dirname(__FILE__) + '/../spec_helper.rb'

describe RocketAMF::Request do  
  it "should handle a set of challeng rules (contains dict)" do
    req = create_request("challengeRules")
    message = req.messages[0].data
    require 'pp'
    raise message.body.pretty_inspect
  end
end
