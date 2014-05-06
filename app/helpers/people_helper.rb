module PeopleHelper
  # Come up with a better way, not repeating from application_helper -
  # probably a generic information displayer (akin to
  # ComasFormBuilder)?
  def label_for_field(model, field)
    [model.class.to_s, field.to_s.humanize].join('|')
  end

  # What columns must be displayed on the public person profile?
  # Returns the proper column names - This is, if the profile mentions
  # a catalog, the referring column (_id) will be returned. All
  # non-existing columns that might be specified will be dropped.
  def columns_for_profile(person)
    begin
      columns = SysConf.value_for('person_profile_fields').
        split(/\s*,\s*/).
        map do |col|
        colref = col + '_id'
        person.class.column_names.include?(col) ? col :
          person.class.column_names.include?(colref) ? colref :
          nil
      end.select {|c| c}
    rescue NoMethodError
      # Probably person_profile_fields is not defined
      return []
    end
  end

  # Build the general personal information for the public profile
  def public_attributes(person)
    columns = person.class.columns
    columns_for_profile(person).map do |attr|
      attr = attr.to_s
      column = columns.select {|c| c.name == attr}[0]
      name = Translation.for(label_for_field(person, attr))

      begin
        # If the value in this field references a catalog, return the
        # corresponding catalog's entry name. Otherwise, just return
        # the text.
        if attr =~ /(.*)_id$/ and
            person.class.connection.tables.include?($1.pluralize) and
            model = $1.classify.constantize and model.is_catalog?
          value = model.find_by_id(person.send(attr)).name
        else
          value = person.send(attr)
        end
      rescue NameError, ActiveRecord::RecordNotFound
        # In case the field looks like a catalog but is not, the
        # previous '$1.classify.constantize' or the subsequent 'find'
        # will fail. Use the value as it is stored. Note that we are
        # guaranteed 'attr' is legal, as we are consuming the list
        # checked at columns_for_profile.
        value = person.send(attr)
      end
      # Don't show fields that have a nil value
      return if value.nil?

      case column.type
      when :text
        redcloth_info_row name, value
      else
        info_row name, value
      end
    end
  end

  def text_for_invite(invite)
    return nil unless invite
    conf = invite.conference
    '<p>%s</p>' %
      (_('You followed an invitation link for the <em>%s</em> conference ' +
         '(%s - %s).') % [conf.name, conf.begins, conf.finishes])
  end

  def link_to_dup(dup,invite)
    return nil unless dup
    dest = {:action => 'login', :login => dup.login}
    dest[:invite] = invite.link if invite
    link_to dup.login, dest
  end

  def link_to_photo(person)
    return '' unless person.has_photo?
    photo = person.photo
    image_tag(photo.url,
              :size => '%dx%d' % [photo.width, photo.height],
              :alt => _('Photo for %s' % person.name))
  end
end
