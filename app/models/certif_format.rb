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

  def height(unit=:pt)
    self.height_of(paper_size, unit)
  end

  def width(unit=:pt)
    self.width_of(paper_size, unit)
  end
end
