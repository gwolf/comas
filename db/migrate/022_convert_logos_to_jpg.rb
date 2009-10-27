class ConvertLogosToJpg < ActiveRecord::Migration
  class Logo < ActiveRecord::Base;end
  def self.up
    Logo.find(:all).each do |logo|
      %w(thumb medium data).each do |size|
        new_img = Magick::Image.from_blob(logo.send(size))[0]
        new_img.format = 'jpg'
        logo.send('%s='%size, new_img.to_blob)
      end
      logo.save!
    end
  end

  def self.down
    Logo.find(:all).each do |logo|
      %w(thumb medium data).each do |size|
        new_img = Magick::Image.from_blob(logo.send(size))[0]
        new_img.format = 'png'
        logo.send('%s='%size, new_img.to_blob)
      end
      logo.save!
    end
  end
end
