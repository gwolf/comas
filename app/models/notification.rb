class Notification < ActionMailer::Base
  class InvalidEmail < Exception; end
  class MustSupplyBody < Exception; end

  # Welcome mail - Sent to everybody at account creation time
  def welcome(person)
    sys_name = SysConf.value_for('title_text')
    recipients person.name_and_email
    base_info(_('Welcome! You have successfully registered at %s') %
              sys_name)
    body :name => person.name,
         :login => person.login,
         :sys_name => sys_name,
         :login_url => login_url
  end

  # Password recovery mail
  def request_passwd(person, ip)
    sess = RescueSession.create_for(person)
    sys_name = SysConf.value_for('title_text')

    recipients person.name_and_email
    base_info(_('New password request for %s') % sys_name)
    body :name => person.name,
         :login => person.login,
         :sys_name => sys_name,
         :ip => ip,
         :login_url => url_for(:only_path => false,
                               :controller => 'people',
                               :action => 'recover',
                               :r_session => sess.link)
  end

  # Mail to send when somebody adds a user as a coauthor
  def added_as_coauthor(new_author, proposal, author)
    recipients new_author.name_and_email
    cc author.name_and_email
    base_info(_("You have been added as a coauthor"))
    body :conference_name => proposal.conference.name,
         :orig_author_name => author.name,
         :new_author_name => new_author.name,
         :proposal_title => proposal.title,
         :proposal_url => url_for(:only_path => false,
                                  :controller => 'proposals',
                                  :action => 'show',
                                  :id => proposal),
         :login_url => login_url
  end

  # Inviting a friend to a conference
  def conference_invitation(invite, invitation_text)
    dest = invite.email
    conf = invite.conference
    sender = invite.sender

    checks_for_open_mails(dest, invitation_text)

    recipients dest
    base_info(_('Invitation to %s, sent by %s') %
              [conf.name, sender.name])
    body(:conference => conf.name,
         :sender_name => sender.name,
         :sender_email => sender.email,
         :conference_url => conf_url(conf),
         :invitation_url => url_for(:only_path => false,
                                    :controller => 'people',
                                    :action => 'new',
                                    :invite => invite.link),
         :invitation_text => invitation_text)
  end

  # Arbitrary administrator-generated mail
  def admin_mail(sender, dest, title, mail_body)
    checks_for_open_mails(dest.email, mail_body)

    recipients dest.name_and_email
    base_info(title)
    body(:disclaimer => mail_disclaimer(_('general information mails'),
                                        sender),
         :mail_body => mail_body)
  end

  # Mail sent to registered conference membres (who opted in)
  def conf_attendees_mail(sender, dest, confs, title, mail_body)
    checks_for_open_mails(dest.email, mail_body)

    recipients dest.name_and_email
    base_info(title)
    body(:disclaimer => mail_disclaimer(_('mails regarding the conferences ' +
                                          'they have signed up for'), sender),
         :mail_body => mail_body)
  end

  private
  # Set basic fields which are common to all of our generated mails
  def base_info(title='')
    from comas_mail_from
    headers 'return-path' => SysConf.value_for('mail-from')
    subject comas_title(title)
  end

  # Basic sanity checks for mails sent with user-supplied data: Email
  # address looks sane? Does it have a nonempty body?
  def checks_for_open_mails(dest, body)
    raise InvalidEmail unless dest =~ RFC822::EmailAddress
    raise MustSupplyBody if body.nil? or body.empty?
  end

  # Generate an URL for the system login
  def login_url
    url_for(:only_path => false,
            :controller => 'people',
            :action => 'login')
  end

  # Generate the URL for the specified conference's information page
  def conf_url(conf)
    url_for(:only_path => false,
            :controller => 'conference',
            :action => 'show',
            :id => conf)
  end

  # This Comas' title (including an easily identifiable prefix)
  def comas_title(title='')
    '[%s] %s' % [SysConf.value_for('title_text'), title]
  end

  # Who should system-generated mails be sent as?
  def comas_mail_from
    '%s <%s>' % [SysConf.value_for('title_text'),
                 SysConf.value_for('mail_from')]
  end

  # Informative text regarding why this mail is sent to a person and
  # detailing how to desubscribe
  def mail_disclaimer(mail_type, sender)
    text = _('============================================================

This mail was sent via the Conference Administration System at %s. It is sent only to people who agreed to receive %s. If you do not want to recive them, please log in to:

%s

Select the "%s" link, and specify which kind of mails you are interested in receiving.

This mail was sent to you by %s, local administrator for this system. If you want to directly contact %s, the registered mail address is %s.
') % [ SysConf.value_for('title_text'), mail_type, login_url,
       _('Personal information'), sender.name, sender.name, sender.email]
  end
end
