class CertifFormat < ActiveRecord::Base
  include PdfDimensions

  has_many(:certif_format_lines, :order => 'y_pos DESC, x_pos DESC',
           :dependent => :destroy)

  validates_presence_of :name, :paper_size, :orientation
  validates_uniqueness_of :name
  validates_inclusion_of :paper_size, :in => PaperSizes
  validates_inclusion_of :orientation, :in => Orientations.keys

  def self.height_of(paper, unit=nil)
    unit ||= sys_units
    paper = paper.to_s.upcase
    convert_unit :pt, unit, Prawn::Document::PageGeometry::SIZES[paper][1]
  end

  def self.width_of(paper, unit=nil)
    unit ||= sys_units
    paper = paper.to_s.upcase
    convert_unit :pt, unit, Prawn::Document::PageGeometry::SIZES[paper][0]
  end

  def self.paper_dimensions(paper)
    unit = abbr_units
    '%.02f x %.02f %s' % [self.height_of(paper, unit),
                          self.width_of(paper, unit),
                          _(unit)]
  end

  def self.for_personal_nametag
    self.find_by_name(SysConf.value_for('personal_nametag_format'))
  end

  def height(unit=:pt)
    self.height_of(paper_size, unit)
  end

  def width(unit=:pt)
    self.width_of(paper_size, unit)
  end

  # Generates the PDF for  this format for the specified person/people
  # and conference. Returns the PDF blob as a string, to be saved to a
  # file or sent to the Web client.
  #
  # If no conference is specified and the format includes a
  # conference-specific line, a CertifFormatLine::ConferenceRequired
  # exception will be raised.
  #
  # If with_boxes is true (default is set to false), each of the field
  # spaces will be outlined and filled — This is meant as an aid when
  # defining formats.
  def generate_pdf_for(people, conference=nil, with_boxes=false)
    pdf = Prawn::Document.new(:page_layout => orientation.to_sym,
                              :page_size => paper_size,
                              :skip_page_creation => true)
#    pdf.stroke_color='000000' # Black is beautiful. Black for teh win!
    people = [people] if people.is_a? Person

    people.each do |person|
      pdf.start_new_page

      certif_format_lines.each do |line|
        line.lay_out_in_pdf(pdf, person, conference, with_boxes)
      end
    end

    pdf.render
  end
end
