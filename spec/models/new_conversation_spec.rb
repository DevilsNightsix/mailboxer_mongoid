require 'spec_helper'

describe MailboxerMongoid::Conversation do

  before do
    @entity1 = FactoryGirl.create(:user)
    @entity2 = FactoryGirl.create(:user)
    @receipt1 = @entity1.send_message(@entity2,"Body","Subject")


    puts '00 ----------------------'
    puts "receipt1: #{@receipt1.to_json}"

    @receipt2 = @entity2.reply_to_all(@receipt1,"Reply body 1")
    @receipt3 = @entity1.reply_to_all(@receipt2,"Reply body 2")
    @receipt4 = @entity2.reply_to_all(@receipt3,"Reply body 3")
    @message1 = @receipt1.notification
    @message4 = @receipt4.notification
    @message1.reload
    @conversation = @message1.conversation

  end

  it "should have proper original message" do
    #@conversation.original_message.should==@message1
  end

end
