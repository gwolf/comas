module ConferencesHelper
  def conf_list_table(confs)
    rows = 0 
    row_classes = list_row_classes
    ret = []
    ret << '<table>' << conf_list_head_row
    ret << confs.map do |conf| 
      rows+=1
      conf_list_row(row_classes[rows%row_classes.size], conf)
    end
    ret << '</table>'

    ret.join("\n")
  end

  def conf_list_head_row
    '<tr class="listing-head">' <<
      [_('Conference'), _('Dates'), ''].map {|col| "<th>#{col}</th>"}.join <<
      '</tr>'
  end

  def conf_list_row(rowclass, conf)
    "<tr class=\"#{rowclass}\">" <<
      [ link_to(conf.name, :controller => 'conferences', 
                :action => 'show', :id => conf),
        "#{conf.begins} - #{conf.finishes}",
        sign_up_person_for_conf_link(@user, conf)
      ].map {|col| "<td>#{col}</td>"}.join <<
      '</tr>'
  end

  def sign_up_person_for_conf_link(user, conf)
    return unless user

    if ! conf.accepts_registrations?
      return _('Registered') if user.conferences.include?(conf)
      return _('Registration closed')
    end

    if user.conferences.include? conf
      return link_to(_('Unregister'),
                     { :controller => 'conferences',
                       :action => 'unregister',
                       :id => conf},
                     { :method => :post,
                       :confirm => _('Confirm: Do you want to unregister ' +
                                     'from "%s"? ') % conf.name})
    else
      return link_to(_('Sign up'),
                     { :controller => 'conferences', 
                       :action => 'sign_up',
                       :id => conf}, 
                     { :method => :post })
    end
  end

end
