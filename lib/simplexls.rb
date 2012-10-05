# -*- coding: utf-8 -*-
### SimpleXLS - A simplistic wrapper for Spreadsheet
#
# Copyright © 2009 Gunnar Wolf <gwolf@gwolf.org>
# Instituto de Investigaciones Económicas, UNAM
#
require 'spreadsheet'
require 'tempfile'

class SimpleXLS
  # Creates a new, empty spreadsheet consisting of a single workbook
  def initialize
    @xls = Spreadsheet::Workbook.new
    @page = @xls.create_worksheet

    @format = {:head => Spreadsheet::Format.new(:weight => :bold,
                                                :color => :blue)
    }

    @curr_row = 0
  end

  # Adds a header-formatted row to the spreadsheet
  def add_header(*row)
    @page.row(@curr_row).default_format = @format[:head]
    add_row(row)
  end

  # Adds a regular row to the spreadsheet
  def add_row(*row)
    @page.row(@curr_row).concat(row.flatten)
    @curr_row += 1
  end

  # Gets the spreadsheet (in binary, XLS format) as a string
  def to_s
    io = Tempfile.new('simplexls')
    @xls.write(io)
    io.rewind
    str = io.read
    io.unlink
    str
  end
end
