class CreateNametagFormats < ActiveRecord::Migration
  def self.up
    create_table :nametag_formats do |t|
      t.column :name, :string
      t.column :h_size, :integer, :null => false
      t.column :v_size, :integer, :null => false
      t.column :v_gap, :integer, :null => false
      t.column :name_width, :integer, :null => false
      t.column :h_start, :integer, :null => false
      t.column :v_start, :integer, :null => false
      t.column :id_bar_hpos, :integer, :null => false
      t.column :id_bar_vpos, :integer, :null => false
      t.column :id_bar_orient, :integer, :null => false
      t.column :id_bar_narrow, :integer, :null => false
      t.column :id_bar_wide, :integer, :null => false
      t.column :id_bar_height, :integer, :null => false
    end
  end

  def self.down
    drop_table :nametag_formats
  end
end
