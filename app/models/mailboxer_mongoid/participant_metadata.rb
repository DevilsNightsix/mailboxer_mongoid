class MailboxerMongoid::ParticipantMetadata
  include Mongoid::Document

  embedded_in :conversation, :class_name => "MailboxerMongoid::Conversation", inverse_of: :participant_metadata

  field :mailbox_type, type: Integer, default: 1
  field :participant_id, type: BSON::ObjectId
  field :participant_type, type: String
  field :conversation_read, type: Boolean, default: false

  def participant=(participant)
    self.participant_id = participant.id
    self.participant_type = participant.class.to_s
  end

end
