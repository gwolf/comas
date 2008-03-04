require File.dirname(__FILE__) + '/../test_helper'

class ConferenceTest < ActiveSupport::TestCase
  def test_require_unique_name
    c1 = new_test_conference
    c2 = new_test_conference
    c1.save
    # A new conference with the same name is not OK
    assert ! c2.valid?
    # Empty names are also forbidden
    c2.name = nil
    assert ! c2.valid?
    # But any other thing is ok
    c2.name = 'Pleaaaaaaase?'
    assert c2.valid?
  end

  def test_valid_begin_and_finish
    c = new_test_conference
    # Require begin/end date to be set
    c.begins = nil
    c.finishes = nil
    assert !c.valid?
    # If they are set in order, it should work
    c.begins = Date.today + 1
    c.finishes = Date.today + 2
    assert c.valid?
    # But if they are not ordered, it should again fail
    c.begins = Date.today + 3
    assert !c.valid?
  end

  def test_cfp_dates
    c = new_test_conference
    # Not specifying CFP dates yields a valid conference, although it should
    # not accept any proposals
    assert c.valid?
    assert !c.accepts_proposals?
    # Specifying only CFP begin date should work
    c.cfp_open_date = c.begins - 10
    assert c.valid?
    assert c.accepts_proposals?
    # Specifying also the end date should work - but limit us not to send
    # any more proposals (begins is defined in new_test_conference to tomorrow)
    c.cfp_close_date = c.begins - 5
    assert c.valid?
    assert !c.accepts_proposals?
    # Don't allow us to specify the CFP to extend after the conference starts
    c.cfp_close_date = c.begins + 1
    assert !c.valid?

    # Specifying only CFP open date allows us to register proposals from that
    # moment on, until conference begins
    c = new_test_conference
    c.cfp_open_date = Date.today - 5
    assert c.accepts_proposals?
    c.begins = Date.today - 3
    assert !c.accepts_proposals?
    # Specifying only CFP close date allows us to register proposals as long
    # as we are before that date
    c.begins = Date.today + 10
    c.finishes = Date.today + 15
    c.cfp_open_date = nil
    c.cfp_close_date = Date.today + 5
    assert c.accepts_proposals?
    c.cfp_close_date = Date.today - 1
    assert !c.accepts_proposals?
  end

  def test_reg_dates
    c = new_test_conference
    # If the conference has not yet finished, even with no registration dates
    # provided, it should accept registrations
    c.reg_open_date = nil
    c.reg_close_date = nil
    assert c.valid?
    assert c.accepts_registrations?
    # Even if it has already started
    c.begins = Date.today - 5
    assert c.accepts_registrations?
    # But not if it has finished.
    c.finishes = Date.today - 1
    assert ! c.accepts_registrations?

    # Reset begin/finish to the future...
    c.begins = Date.today + 1
    c.finishes = Date.today + 2

    # Specifying the registration window: Only sane values, please
    # Close date cannot be after the conference finishes
    c.reg_close_date = c.finishes + 3
    assert !c.valid?
    # Registration start date cannot be after it closes
    c.reg_close_date = Date.today - 1
    c.reg_open_date = Date.today
    assert !c.valid?

    # Ok, back to sane values...
    c.reg_open_date = Date.today - 10
    c.reg_close_date = Date.today - 5
    assert c.valid?
    # Registration is closed!
    assert ! c.accepts_registrations?
    # But if reg_close_date is not specified, it should be valid. And allowed.
    c.reg_close_date = nil
    assert c.valid?
    assert c.accepts_registrations?
    # If close date is specified (and in the future), and no open date is
    # specified, we are allowed
    c.reg_open_date = nil
    c.reg_close_date = Date.today + 1
    assert c.valid?
    assert c.accepts_registrations?
    
  end

  private
  def new_test_conference
    Conference.new(:name => 'A test conference', 
                   :descr => 'This is a test conference, not for real',
                   :begins => Date.today + 1,
                   :finishes => Date.today + 2)
  end
end
