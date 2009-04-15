class CertifFormat < ActiveRecord::Base
  Orientations = {'portrait' => _('Portrait'), 'landscape' => _('Landscape')}
  PaperSizes = PDF::Writer::PAGE_SIZES.keys

  has_many(:certif_format_lines, :order => 'y_pos DESC, x_pos DESC',
           :dependent => :destroy)

  validates_presence_of :name, :paper_size, :orientation
  validates_uniqueness_of :name
  validates_inclusion_of :paper_size, :in => PaperSizes
  validates_inclusion_of :orientation, :in => Orientations.keys

  def self.height_of(paper, unit=nil)
    unit ||= SysConf.value_for(:page_units)
    points_to unit, PDF::Writer::PAGE_SIZES[paper][3]
  end

  def self.width_of(paper, unit=nil)
    unit ||= SysConf.value_for(:page_units)
    points_to unit, PDF::Writer::PAGE_SIZES[paper][2]
  end

  def self.paper_dimensions(paper)
    unit = SysConf.value_for(:page_units)
    '%.02f x %.02f %s' % [self.height_of(paper, unit),
                          self.width_of(paper, unit), 
                          unit]
  end

  def height(unit=:pt)
    self.height_of(paper_size, unit)
  end

  def width(unit=:pt)
    self.width_of(paper_size, unit)
  end

  private
  def self.points_to(unit, amount)
    divisors = {:pt => 1.0, 
      :in => 72.0, 
      :cm => 28.3446712018141
    }

    scale = divisors[unit.to_sym] or 
      raise TypeError, _('Unknown unit specified: %s') % unit

    amount / scale
  end
end
