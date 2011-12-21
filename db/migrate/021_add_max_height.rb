class AddMaxHeight < ActiveRecord::Migration
  class CertifFormatLine < ActiveRecord::Base;end
  def self.up
    add_column :certif_format_lines, :max_height, :integer
    CertifFormatLine.find(:all).map do |l|
      l.max_height = l.font_size * 1.3
      l.save
    end
  end

  def self.down
    remove_column :certif_format_lines, :max_height
  end
end
