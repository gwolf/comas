module PdfDimensions
  include GetText
  Orientations = {'portrait' => _('Portrait'), 'landscape' => _('Landscape')}
  PaperSizes = PDF::Writer::PAGE_SIZES.keys

  module ClassMethods
    def human_units
      SysConf.value_for(:page_units)
    end

    def convert_unit(from, to, amount)
      # Our base unit is points. If a conversion between any two other
      # units is requested, it will go through points first.
      divisors = {:pt => 1.0, 
        :in => 72.0, 
        :cm => 28.3446712018141
      }

      from_scale = divisors[from.to_sym] or 
        raise TypeError, _('Unknown source unit specified: %s') % from
      to_scale = divisors[to.to_sym] or
        raise TypeError, _('Unknown target unit specified: %s') % to

      amount.to_f * from_scale / to_scale
#       scale = divisors[to.to_sym] or 
#         raise TypeError, _('Unknown unit specified: %s') % unit

#       amount / scale
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  def convert_unit(from, to, amount)
    self.class.convert_unit(from, to, amount)
  end

  def points_to_human(amount)
    convert_unit :pt, self.class.human_units, amount
  end

  def human_to_points(amount)
    convert_unit self.class.human_units, :pt, amount
  end
end
