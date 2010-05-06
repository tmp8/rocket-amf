require File.dirname(__FILE__) + '/../spec_helper.rb'

describe RocketAMF::Request do
  it "should handle remoting message from remote object" do
    req = create_request("remotingMessage.bin")

    req.headers.length.should == 0
    req.messages.length.should == 1
    message = req.messages[0].data
    message.should be_a(RocketAMF::Values::RemotingMessage)
    message.messageId.should == "FE4AF2BC-DD3C-5470-05D8-9971D51FF89D"
    message.body.should == [true]
  end

  it "should handle command message from remote object" do
    req = create_request("commandMessage.bin")

    req.headers.length.should == 0
    req.messages.length.should == 1
    message = req.messages[0].data
    message.should be_a(RocketAMF::Values::CommandMessage)
    message.messageId.should == "7B0ACE15-8D57-6AE5-B9D4-99C2D32C8246"
    message.body.should == {}
  end
  
  it "should handle a request with a dict with data" do
    req = create_request("requestWithDict")
    req.headers.length.should == 0
    req.messages.length.should == 1
    message = req.messages[0].data
    message.should be_a(RocketAMF::Values::RemotingMessage)
    message.messageId.should == "87E5329C-2133-B351-DF53-6E38E9A576A2"
    message.body.should == [{:dict=>{"test"=>"test", "key"=>"value", "bool"=>true}, :end=>"end", :alias=>"Challenge"}]
  end
end
