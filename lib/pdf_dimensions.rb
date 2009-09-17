module PdfDimensions
  include GetText
  Orientations = {:portrait => _('Portrait'), :landscape => _('Landscape')}
  PaperSizes = Prawn::Document::PageGeometry::SIZES.keys
  # Our base unit is points, :divisor marks the relation of any other
  # unit to points.
  #
  # Prawn::Measurments handles many more units (cm, dm, ft, in, m, mm,
  # pt, yd), but as they are very seldom used in this domain... For
  # simplicity sake, lets just ignore them.
  ValidUnits = {
    :pt => {
      :divisor => 1.pt,
      :full => _('points'), 
      :abbr => _('pt')},
    :cm => {
      :divisor => 1.cm,
      :full => _('centimeters'), 
      :abbr => _('cm')},
    :in => {
      :divisor => 1.in,
      :full => _('inches'), 
      :abbr => _('in')}
  }

  # If we were implementing PDF generation for the first time, based
  # on Prawn, this module might be basically pointless (as it deals
  # with converting between different measurement systems, and is
  # mostly covered by prawn/measurment_extensions). However, it is
  # still handy and provides some protection (and
  # operator-friendliness), so... We keep it.
  module ClassMethods
    def convert_unit(from, to, amount)
      from_scale = ValidUnits[from.to_sym][:divisor] or 
        raise TypeError, _('Unknown source unit specified: %s') % from
      to_scale = ValidUnits[to.to_sym][:divisor] or
        raise TypeError, _('Unknown target unit specified: %s') % to

      amount.to_f * from_scale / to_scale
    end

    def abbr_units
      ValidUnits[sys_units][:abbr]
    end

    def full_units
      ValidUnits[sys_units][:full]
    end

    def sys_units
      begin
        unit = SysConf.value_for(:page_units).to_sym
      rescue NoMethodError
        raise TypeError, _('Systemwide page units (SysConf key page_units) ' +
                           'has not yet been defined')
      end
      raise TypeError, _('Unknown page units %s in system configuration') % 
        unit unless ValidUnits.has_key?(unit)
      unit
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  def points_to_human(amount)
    convert_unit :pt, sys_units, amount
  end

  def human_to_points(amount)
    convert_unit sys_units, :pt, amount
  end

  def convert_unit(from, to, amount)
    self.class.convert_unit(from, to, amount)
  end

  def abbr_units; self.class.abbr_units; end
  def full_units; self.class.full_units; end
  def sys_units; self.class.sys_units; end
end
