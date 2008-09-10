class Notification < ActionMailer::Base
  def welcome(person)
    sys_name = Sysconf.value_for('title_text')
    recipients person.name_and_email
    from SysConf.value_for('mail_from')
    subject _('Welcome! You have successfully registered at %s') % 
      sys_name
    body :name => person.name, 
         :login => person.login,
         :sys_name => sys_name
         :login_url => url_for(:only_path => false,
                               :controller => 'people',
                               :action => 'login'),
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
end
