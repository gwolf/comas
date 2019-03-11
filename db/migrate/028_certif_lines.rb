class CertifLines < ActiveRecord::Migration
  def self.up
    add_column :conferences, :pre_title, :string
    add_column :conferences, :post_title, :string
    add_column :conferences, :conf_dates, :string
    change_column_default :conferences, :manages_proposals, false
  end

  def self.down
    remove_column :conferences, :pre_title
    remove_column :conferences, :post_title
    remove_column :conferences, :conf_dates
  end
end
