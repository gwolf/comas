#--
# ClassInherit
#
# Copyright (c) 2005 Thomas Sawyer
#
# Ruby License
#
# This module is free software. You may use, modify, and/or redistribute this
# software under the same terms as Ruby.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.
#
# ==========================================================================
#  REVISION HISTORY
# ==========================================================================
#  2005-11-29 trans
#    Version "2.0". Improved by adopting old #class_inherit functionality
#    as well, i.e. ClassInherit module now will be inherited down
#    the Hierarchy chain.
#
#  2005-04-28 trans
#    Reimplemented for Calibre based on Nabu's ClassMethods work.
# ==========================================================================
#
# CREDIT Credit is due Nobu and Ulysses.
#
#++

#:title: ClassInherit
#
# This framework provides a very convenient way to have modules
# pass along class methods in the inheritance chain.
#
# Presently in Ruby the class/module methods of a module
# are not inherited when a module is included --contrary to
# the behavior of classes themselves when they are subclassed.
# To achieve the same behavior with modules requires some clever
# Ruby karate. ClassInherit provides a nice solution.
# Simply place the class inheritable methods in the block 
# parameter of the special module method ClassInherit.
#
#   module Mix
#     def inst_meth
#       puts 'inst_meth'
#     end
#
#     ClassInherit do
#       def class_meth
#         "Class Method!"
#       end
#     end
#   end
#
#   class X
#     include Mix
#   end
#
#   X.class_meth  #=> "Class Method!"
#
# ClassInherit is a capitalized method. This is used because it
# indeed creates (or reopens) a ClassInherit module in which
# the given block is evaluated, then the ClassInherit module
# is extended against the current module.
#
# The above is actually equivalent to putting the class/module 
# methods in a nested ClassInherit module and extending it
# module _manually_, eg.
#
#   module Mix
#     def inst_meth
#       puts 'inst_meth'
#     end
#
#     module ClassInherit
#       def class_meth
#         "Class Method!"
#       end
#     end
#
#     extend ClassInherit
#   end
#
#   class X
#     include Mix
#   end
#
#   X.class_meth  #=> "Class Method!"
#
# Lastly, #class_inherit is an available alias for #ClassInherit
# if you prefer only lowercase methods.
#
# == Notes
#
# Just a quick comment on the need for this behavior.
#
# A module is an encapsulation of code, hence when a module is included
# (or extends), the module itself should have discretion over how it
# effects the receiving class/module. That is the very embodiment of
# encapsulation. Having it otherwise, as Ruby now does, stymies the
# practice --and we end up with "hacks" to compensate.
#
# Ruby would be much improved by making this bevaivor standard.
# And making non-inheritance the exception, which is alwasy easy
# enough to achieve: jsut put the code in a separate
# (and thus uninherited) module.
#
# == Author(s)
#
# * Thomas Sawyer
# * Nobu Nakada
# * Ulysses
#

class Module

  alias_method :append_features_without_classinherit, :append_features

  def append_features( base )
    result = append_features_without_classinherit( base )
    if const_defined?( :ClassInherit )
      base.extend( self::ClassInherit )
      unless base.is_a?( Class )
        unless base.const_defined?( :ClassInherit )
          base.const_set( :ClassInherit, Module.new )
        end
        my = self
        base::ClassInherit.class_eval do
          include my::ClassInherit
        end
      end
    end
    result
  end

  def ClassInherit( &yld )
    if const_defined?( :ClassInherit )
      self::ClassInherit.class_eval( &yld )
    else
      self.const_set( :ClassInherit, Module.new( &yld ) )
    end
    extend( self::ClassInherit )
    self::ClassInherit
  end

  # For compatibility with old rendition
  alias_method :class_inherit, :ClassInherit

end

class Class
  undef_method :ClassInherit
  undef_method :class_inherit
end


#  _____         _
# |_   _|__  ___| |_
#   | |/ _ \/ __| __|
#   | |  __/\__ \ |_
#   |_|\___||___/\__|
#

=begin test

  require 'test/unit'

  class TC_ClassInherit < Test::Unit::TestCase

    # fixture

    module N
      ClassInherit do
        def n ; 43 ; end
      end
      #extend ClassInherit
    end

    class X
      include N
      def n ; 11 ; end
    end

    module K
      include N
      ClassInherit do
        def n ; super + 1 ; end
      end
    end

    class Z
      include K
    end

    # tests

    def test_01
      assert_equal( 43, N.n )
    end
    def test_02
      assert_equal( 43, X.n )
    end
    def test_03
      assert_equal( 11, X.new.n )
    end
    def test_04
      assert_equal( 44, K.n )
    end
    def test_05
      assert_equal( 44, Z.n )
    end

  end

=end
