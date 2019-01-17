class AngleForCertifFormatLines < ActiveRecord::Migration
  def self.up
    add_column :certif_format_lines, :angle, :integer, :default => 0, :null => false
  end
  def self.down
    remove_column :certif_format_lines, :angle
  end
end
