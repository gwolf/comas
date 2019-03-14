# -*- coding: utf-8 -*-
class CertifFormatLine < ActiveRecord::Base
  include ActionController::UrlWriter
  class ConferenceRequired < Exception; end
  include PdfDimensions
  Justifications = %w(left center right full)
  ContentSources = {0 => _('Static'),
    1 => _('Person'),
    2 => _('Conference'),
    -1 => _('Empty (frame)')
  }

  belongs_to :certif_format

  before_validation do |lin|
    # If an empty frame is requested, an unbreakable space should be
    # used as content (in order for the validates_presence_of check
    # not to be upset, and in order not to surprise the user)
    lin.content = ' ' if lin.content_source == -1
  end

  validates_presence_of(:certif_format_id, :content_source, :content,
                        :x_pos, :y_pos, :justification)
  validates_numericality_of(:content_source, :x_pos, :y_pos, :max_width)
  validates_numericality_of :font_size, :allow_nil => true
  validates_numericality_of :angle, :greater_than_or_equal_to => 0, :less_than => 360
  validates_inclusion_of :content_source, :in => ContentSources.keys
  validates_inclusion_of :justification, :in => Justifications
  validates_associated :certif_format

  # font_size <= 0: Default font size (Prawn::Document.new.font_size)

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

  def lay_out_in_pdf(pdf, person, conference, with_boxes=false)
    # For the future, it might be nice to provide for nested
    # bounding boxes. As of right now, KISS.
    pdf.bounding_box([pdf.bounds.left + x_pos, pdf.bounds.bottom + y_pos],
                     :width => max_width, :height => max_height) do
      pdf.rotate(angle, :origin => [0,0]) do
        pdf.font_size(font_size)
        text = value_for(person, conference)
        text = '' if text.nil?

        # Handle all special-casing, yay!
        if content_source == -1
          # Just draw the empty frame
          pdf.stroke_bounds
        elsif content == 'image' and dynamic_source?
          pdf.image(StringIO.new(text),
                    :at => [pdf.bounds.left, pdf.bounds.top],
                    :fit => [pdf.bounds.width, pdf.bounds.height],
                    :position => justification.to_sym,
                    :vposition => justification.to_sym) unless text.nil?
        elsif content == 'id+code' and dynamic_source?
          # If a person or conference's «id+code» are requested, we lay
          # them out as barcodes for their id, not just as text.
          barcode_box(pdf, text)
        elsif content == 'id+qr' and dynamic_source?
          qr_box(pdf, text)
        else
          # Finally, the base case: Regular text appears as it should.
          pdf.text(text, :align => justification.to_sym, :overflow => :shrink_to_fit)
        end

        # When testing formats, the user might want to show boxes
        # around and crossing each element
        if with_boxes
          stroke = pdf.stroke_color
          pdf.stroke_color = 'CBCBE1'
          pdf.stroke_bounds
          pdf.line([pdf.bounds.left, pdf.bounds.bottom],
                   [pdf.bounds.right, pdf.bounds.top])
          pdf.line([pdf.bounds.right, pdf.bounds.bottom],
                   [pdf.bounds.left, pdf.bounds.top])
          pdf.stroke_color = stroke
        end
      end
    end
  end

  def human_max_width=(new)
    self.max_width = human_to_points(new)
  end

  def human_max_height=(new)
    self.max_height = human_to_points(new)
  end

  def dynamic_source?
    [1, 2].include?(content_source)
  end

  private
  def value_for(person,conference)
    return '' if content_source == -1
    return content if content_source == 0

    # So we are dealing with a dynamic source...
    raise ConferenceRequired if content_source == 2 and conference.nil?
    obj = content_source == 1 ? person : conference

    # Special-cased pseudoattributes
    case content
    when 'id+code'
      # Might be conference or person, both have an ID
      return obj.id
    when 'id+qr'
      # Compose the person and conference IDs into a single string
      return '%s/%05d/%05d' % [SysConf.value_for('verif_url'),
                               conference.id.to_s, person.id.to_s]
    when 'image'
      img = obj==person ? obj.photo : obj.logo
      return img ? img.data : nil
    else
      return obj.send(content) if obj.respond_to? content
      raise NoMethodError, _('Undefined attribute %s for %s in format ' <<
                             'line %d (%d)') % [content, obj.class,
                                                id, certif_format_id]
    end
  end

  # Compound bounding box with the barcode and the text elements
  def barcode_box(pdf, value)
    text_height = font_size*1.5
    code_height = pdf.bounds.height - text_height
    code = '%05d' % value

    # Text below
    pdf.bounding_box([pdf.bounds.left, pdf.bounds.top - code_height],
                     :width => pdf.bounds.width, :height => text_height) do
      pdf.text(code, :align => justification.to_sym, :overflow => :shrink_to_fit)
    end

    # Barcode above
    pdf.bounding_box([pdf.bounds.left, pdf.bounds.top],
                     :width => pdf.bounds.width, :height => code_height) do
      barcode = Barby::Code39.new(code)
      barcode.annotate_pdf(pdf, :xdim => 0.75, :height => code_height * 0.8)
    end
  end

  def qr_box(pdf, code)
    text_height = font_size * 1.5

    # QRs are square, so we take its width from its height. The qr_box
    # should be, of course, wide and short.
    code_width = code_height = pdf.bounds.height

    # QR code to the left.
    #
    pdf.bounding_box([pdf.bounds.left, pdf.bounds.top],
                     :width => code_width, :height => code_height) do
      barcode = Barby::QrCode.new(code)
      barcode.annotate_pdf(pdf, :xdim => 1.5, :height => code_height)
    end

    # Text to the right of the QR code.
    pdf.bounding_box([pdf.bounds.left + code_width, pdf.bounds.top - code_width + text_height],
                     :width => pdf.bounds.width - code_width, :height => text_height) do
      pdf.text(_("<color rgb='CBCBE1'>%s <link href='%s'>%s</link></color>") % 
               [SysConf.value_for('personal_certificate_legend'), code, code] , 
               :align => justification.to_sym, 
               :color => 'CBCBE1',
               :inline_format => true, 
               :overflow => :shrink_to_fit)
    end
  end
end
