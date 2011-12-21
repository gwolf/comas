class ConfInvite < ActiveRecord::Base
  belongs_to :conference
  belongs_to :sender, :class_name => 'Person', :foreign_key => 'sender_id'
  belongs_to :claimer, :class_name => 'Person', :foreign_key => 'claimer_id'

  validates_presence_of :conference_id
  validates_presence_of :sender_id
  validates_presence_of :email
  validates_presence_of :link
  validates_associated :conference
  validates_associated :sender
  validates_associated :claimer
  validates_uniqueness_of :link
  validates_format_of :email, :with => RFC822::EmailAddress

  # Shortcut to create an invite with the needed information,
  # auto-filling the link with a random string. Note that this method
  # will save the ConfInvite to the database before returning.
  def self.for(conference, inviter, email, firstname='', famname='')
    invite = self.new(:conference => conference,
                      :sender => inviter,
                      :email => email,
                      :firstname => firstname,
                      :famname => famname,
                      :link => Digest::MD5.hexdigest(String.random(16)))
    invite.save!
    invite
  end

  def accept(person)
    transaction do
      self.claimer = person
      self.conference.people << person
      self.save
    end
  end

  # Has this invitation been claimed?
  def claimed?
    !claimer_id.nil?
  end
end
