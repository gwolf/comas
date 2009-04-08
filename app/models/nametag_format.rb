class NametagFormat < ActiveRecord::Base
  %w(name h_size v_size v_gap name_width h_start v_start id_bar_hpos 
     id_bar_vpos id_bar_orient id_bar_narrow id_bar_wide 
     id_bar_height).each do |attr|
    validates_numericality_of attr
    validates_presence_of attr
  end

  validates_inclusion_of :id_bar_orient, :in => 0..3
  validates_inclusion_of :id_bar_narrow, :in => 1..10
  validates_inclusion_of :id_bar_wide, :in => 2..30

  Defaults = {:name_width => 12, 
    :h_start => 30,
    :v_start => 5,
    :id_bar_hpos => 480,
    :id_bar_vpos => 30, 
    :id_bar_orient => 1,
    :id_bar_narrow => 2,
    :id_bar_wide => 4,
    :id_bar_height => 70
  }

  def initialize (params={})
    super
    Defaults.keys.each {|k| params[k] ||= Defaults[k]}
    params.keys.each {|k| self[k] = params[k]}
  end

  def generate_for(person)
    ['Q%d,%d' % [v_size, v_gap],
     'q%d' % h_size,
     'N',
     text_line(person.firstname, h_start, v_start),
     text_line(person.famname, h_start, v_start + 50),
     text_line(person.email, h_start, v_start + 100, 3, false),
     barcode_line(person),
     'P',
     ''
    ].join("\n")
  end

  private
  def barcode_line(person)
    id_bar_type = 1
    print_numbers = 'B'
    'B%d,%d,%d,%d,%d,%d,%d,%s,%s' % [id_bar_hpos, id_bar_vpos, 
                                       id_bar_orient, id_bar_type,
                                       id_bar_narrow, id_bar_wide,
                                       id_bar_height, print_numbers,
                                       person.id]
  end

  def text_line(text, hpos, vpos, fontsize=4, dblheight=true, reverse=false)
    # fontsize: 1 -> 4pt, 2 -> 6pt, 3 => 8pt, 4 => 10pt, 5 => 21pt
    rotation = 0
    wide = text.size <= name_width ? 2 : 1
    tall = dblheight ? 2 : 1
    reverse = reverse ? 'R' : 'N'
    'A%d,%d,%d,%d,%d,%d,%s,%s,"%s"' % [hpos, vpos, rotation, fontsize, 
                                    wide, tall, id_bar_height, reverse, 
                                       text]
  end
end
