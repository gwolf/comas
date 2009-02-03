module PeopleHelper
  # Come up with a better way, not repeating from application_helper -
  # probably a generic information displayer (akin to
  # ComasFormBuilder)?
  def label_for_field(model, field)
    [model.class.to_s, field.to_s.humanize].join('|')
  end

  def public_attributes(person)
    person.public_attributes.map do |attr|
      name = label_for_field(person, attr.name)
      value = person.send(attr.name)
      case attr.type
      when :text
        redcloth_info_row name, value
      else
        info_row name, value
      end
    end
  end
end
