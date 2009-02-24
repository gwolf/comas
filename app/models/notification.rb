class Notification < ActionMailer::Base
  class InvalidEmail < Exception; end
  def welcome(person)
    sys_name = SysConf.value_for('title_text')
    recipients person.name_and_email
    from SysConf.value_for('mail_from')
    subject _('Welcome! You have successfully registered at %s') % 
      sys_name
    body :name => person.name, 
         :login => person.login,
         :sys_name => sys_name,
         :login_url => url_for(:only_path => false,
                               :controller => 'people',
                               :action => 'login')
  end

  def request_passwd(person, ip)
    sess = RescueSession.create_for(person)
    sys_name = SysConf.value_for('title_text')

    recipients person.name_and_email
    from SysConf.value_for('mail_from')
    subject _('New password request for %s') % sys_name
    body :name => person.name,
         :login => person.login,
         :sys_name => sys_name,
         :ip => ip,
         :login_url => url_for(:only_path => false,
                               :controller => 'people',
                               :action => 'recover',
                               :r_session => sess.link)
  end

  def added_as_coauthor(new_author, proposal, author)
    recipients new_author.name_and_email
    cc author.name_and_email
    from SysConf.value_for('mail_from')
    subject _("You have been added as a coauthor")
    body :conference_name => proposal.conference.name,
         :orig_author_name => author.name, 
         :new_author_name => new_author.name,
         :proposal_title => proposal.title,
         :proposal_url => url_for(:only_path => false,
                                  :controller => 'proposals',
                                  :action => 'show',
                                  :id => proposal),
         :login_url => url_for(:only_path => false,
                               :controller => 'people',
                               :action => 'login')
  end

  def conference_invitation(sender, dest, conference, invitation_text)
    dest =~ RFC822::EmailAddress or raise InvalidEmail

    recipients dest
    from SysConf.value_for('mail_from')
    subject _('Invitation to %s, sent by %s') % [conference.name, sender.name]
    body :conference => conference.name,
         :sender_name => sender.name,
         :sender_email => sender.email,
         :conference_url => url_for(:only_path => false,
                                    :controller => 'conferences',
                                    :action => 'show',
                                    :id => conference),
         :invitation_text => invitation_text
  end
end
