#!/usr/bin/ruby
# coding: utf-8
require 'barby'
require 'barby/barcode/code_39'
require 'barby/outputter/prawn_outputter'
require 'prawn'
require 'prawn/measurement_extensions'

begin
  Person
rescue NameError
  class Person
    attr_accessor :id, :name, :email, :organization
    def initialize(data={})
      [:id, :name, :email, :organization].each {|attr| self.send("#{attr}=", data[attr])}
    end
  end
end

class String
  # Generates a random string of the specified length (defaults to
  # 8). This string will be composed of characters between 48 and 126
  def self.random(length=8)
    low = 65
    high = 90
    Array.new(length).map {(rand(high - low) + low).chr}.join
  end
end

class Gafetes < Prawn::Document
  PageSize = 'LETTER'
  PageLayout = :portrait
  PeoplePerPage = 5
  ImgWidth = 7.45.cm
  ImgHeight = 10.9.cm

  # If we get an over-full bounding box, ignore the limit (rather than
  # jumping to a new page)
  class Prawn::Document::BoundingBox
    def move_past_bottom;end
  end

  def initialize(bgimage=nil, people=[])
    @bgimage = bgimage
    @people = people
    super(:page_size => PageSize, :page_layout => PageLayout)

    repeat(:all, :dynamic => true) do
      draw_text "#{@people.size} participantes registrados a #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}",
                :at => [bounds.top_left]
      draw_text '%d / %d' % [page_number, @people.size / PeoplePerPage + 1],
                :at => [bounds.right/2, 0]
    end

    build
  end

  def write(filename='/tmp/gafetes.pdf')
    File.open(filename, 'w') {|f| f.write(self.render) }
  end


  def self.sample_run

    people = []
    8.times do
      people << Person.new(:id => rand(20000),
                           :name => '%s %s' % [String.random(rand(15)).capitalize,
                                               String.random(rand(15)).capitalize],
                           :email => ('%s@%s.%s' % [String.random(rand(10)),
                                                    String.random(rand(10)),
                                                    String.random(rand(2)+1)]).downcase,
                           :organization => '%s %s %s %s %s' % [String.random(rand(10)).capitalize,
                                                                String.random(rand(10)).capitalize,
                                                                String.random(rand(10)).capitalize,
                                                                String.random(rand(10)).capitalize,
                                                                String.random(rand(10)).capitalize,
                                                                String.random(rand(10)).capitalize]
                          )
    end
    gafetes = self.new(people)
    gafetes.write
  end

  protected
  def build
    #stroke_axis
    @people.each_with_index do |person, i|
      if i % PeoplePerPage == 0 and i > 0
        start_new_page
      end
      gafete(i % PeoplePerPage, person)
    end
  end

  def gafete(num, person)
#    puts "Gafete #{num}"
    case num
    when 0
      rot = 0
      left = bounds.right - ImgWidth
      top = bounds.top - 1.45.cm
    when 1
      rot = 0
      left = bounds.right - ImgWidth
      top = bounds.top - ImgHeight - 1.45.cm
    when 2
      rot = 90
      left = bounds.left - 1.cm
      top = bounds.top - 3.3.cm
    when 3
      rot = 90
      left = bounds.left - 1.cm + ImgWidth
      top = bounds.top - 3.3.cm
    when 4
      rot = 90
      left = bounds.left - 1.cm + 2*ImgWidth
      top = bounds.top - 3.3.cm
    end

    rotate(rot, :origin => [bounds.right / 2, bounds.top / 2]) do
      bounding_box([left, top ], :width => ImgWidth, :height => ImgHeight) do
        stroke_bounds
        image(@bgimage, :width => ImgWidth, :height => ImgHeight) unless @bgimage.nil?
        # 'stroke_circle' not available in barby 0.3.2
        #stroke_circle([bounds.right / 2, bounds.top - 0.35.cm], 0.15.cm)
        # Label
        bounding_box([0, 6.cm], :width => ImgWidth, :height => 2.2.cm) do
          # Barcode
          bounding_box([0,bounds.top], :height => bounds.top, :width => bounds.top) do
            barcode = Barby::Code39.new(person.id.to_s)
            barcode.annotate_pdf(self, :xdim => 0.7, :height => (bounds.top * 0.7), :x => 0.15.cm)
            draw_text person.id, :size => 10, :at => [5.mm, bounds.top * 0.85]
          end
          # Name and mail
          bounding_box([bounds.top + 0.5.cm, bounds.top], :height => bounds.top, :width => (bounds.right-bounds.top) * 0.9) do
            text_box(person.name,
                     :size => 18,
                     :at => [0,bounds.top],
                     :width => bounds.right,
                     :height => bounds.top/2,
                     :overflow => :shrink_to_fit,
                     :align => :center)
            text_box(person.email,
                     :size => 12,
                     :at => [0, bounds.top/2],
                     :width => bounds.right,
                     :height => bounds.top/4,
                     :overflow => :shrink_to_fit,
                     :align => :center)
            text_box(person.organization,
                     :size => 12,
                     :at => [0, bounds.top/4],
                     :width => bounds.right,
                     :height => bounds.top/4,
                     :overflow => :shrink_to_fit,
                     :align => :center)

          end
        end
      end
    end
  end
end
