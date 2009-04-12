class CertifFormat < ActiveRecord::Base
  Orientations = {'portrait' => _('Portrait'), 'landscape' => _('Landscape')}
  PaperSizes = PDF::Writer::PAGE_SIZES.keys

  has_many :certif_format_lines, :order => 'y_pos DESC, x_pos DESC'

  validates_presence_of :name, :paper_size, :orientation
  validates_uniqueness_of :name
  validates_inclusion_of :paper_size, :in => PaperSizes
  validates_inclusion_of :orientation, :in => Orientations.keys
end
