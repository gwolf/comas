class AdminTask < ActiveRecord::Base;end
class SysConf < ActiveRecord::Base;end
class CreateCertifFormats < ActiveRecord::Migration
  def self.up
    create_table :certif_formats do |t|
      # :orientation's meaning (true = portrait, false = landscape) is
      # specified (hard-coded) in model
      t.column :name, :string, :null => false
      t.column :paper_size, :string, :null => false
      t.column :orientation, :string, :null => false
    end

    create_table :certif_format_lines do |t|
      # Valid :content_source, :justification are specified and
      # hard-coded in the corresponding model
      t.column :content_source, :integer, :null => false 
      t.column :content, :string, :null => false
      t.column :x_pos, :integer, :null => false
      t.column :y_pos, :integer, :null => false
      t.column :max_width, :integer, :null => false
      t.column :font_size, :integer
      t.column :justification, :string, :null => false
    end
    add_reference(:certif_format_lines, :certif_formats, :null => false)

    SysConf.new(:key => 'page_units',
                :descr => 'Preferred units in which you measure page sizes ' +
                '(cm, in, pt)',
                :value => 'cm').save!
    AdminTask.new(:name => 'Certificates generation',
                  :sys_name => 'certif_gen').save!
  end

  def self.down
    AdminTask.find_by_sys_name('certif_gen').destroy
    SysConf.find_by_key('page_units').destroy
    drop_table :certif_format_lines
    drop_table :certif_formats
  end
end
