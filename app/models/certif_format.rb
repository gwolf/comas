class CertifFormat < ActiveRecord::Base
  Orientations = {true => :portrait, false => :landscape}
  PaperSizes = PDF::Writer::PAGE_SIZES.keys

  has_many :certif_format_lines, :order => 'y_pos, x_pos'


  validates_presence_of :name, :paper_size
  validates_inclusion_of :paper_size, :in => PaperSizes
end
