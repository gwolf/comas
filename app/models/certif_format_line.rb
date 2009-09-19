class CertifFormatLine < ActiveRecord::Base
  include PdfDimensions
  Justifications = %w(left center right full)
  ContentSources = {0 => _('Static'),
    1 => _('Person'),
    2 => _('Conference')}

  belongs_to :certif_format

  validates_presence_of(:certif_format_id, :content_source, :content, 
                        :x_pos, :y_pos, :justification)
  validates_numericality_of(:content_source, :x_pos, :y_pos, :max_width)
  validates_numericality_of :font_size, :allow_nil => true
  validates_inclusion_of :content_source, :in => ContentSources.keys
  validates_inclusion_of :justification, :in => Justifications
  validates_associated :certif_format

  # font_size <= 0: Default font size (Prawn::Document.new.font_size)

  def text_for(person,conference)
    case content_source
    when 0
      return content
    when 1
      obj = person 
    when 2
      obj = conference
    else
      raise NoMethodError, _('Undefined content source %d for %d (%d)') % 
        [content_source, id, certif_format_id]
    end

    return obj.send(content) if
      obj.class.column_names.include? content
    raise NoMethodError, _('Undefined attribute %s for %s in format ' <<
                           'line %d (%d)') % [content, obj.class, 
                                              id, certif_format_id]
  end

  def human_x_pos
    '%.2f' % points_to_human(x_pos) unless x_pos.nil?
  end

  def human_x_pos=(new)
    self.x_pos = human_to_points(new)
  end

  def human_y_pos
    '%.2f' % points_to_human(y_pos) unless y_pos.nil?
  end
  def human_y_pos=(new)
    self.y_pos = human_to_points(new)
  end

  def human_max_width
    '%.2f' % points_to_human(max_width) unless max_width.nil?
  end

  def human_max_height
    '%.2f' % points_to_human(max_height) unless max_height.nil?
  end

  def human_max_width=(new)
    self.max_width = human_to_points(new)
  end
end
