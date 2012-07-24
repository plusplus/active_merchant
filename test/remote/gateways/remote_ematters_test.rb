require 'test_helper'

class RemoteEmattersTest < Test::Unit::TestCase

  def setup

    @gateway = EmattersGateway.new(fixtures(:ematters))

    @amount = 100
    @credit_card = credit_card('4557 0130 0031 4262',
      :month => 12,
      :year => 2020,
      name: 'MR J Doe')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => rand(3400),
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved.', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal '715', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction approved.', auth.message
    assert capture = @gateway.capture(@amount, auth.authorization, @options)

    assert_success capture
    assert_equal 'Transaction approved.', capture.message

  end

  # def test_authorize_and_capture
  #   amount = @amount
  #   assert auth = @gateway.authorize(amount, @credit_card, @options)
  #   assert_success auth
  #   assert_equal 'Success', auth.message
  #   assert auth.authorization
  #   assert capture = @gateway.capture(amount, auth.authorization)
  #   assert_success capture
  # end

  # def test_failed_capture
  #   assert response = @gateway.capture(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  # end

  def test_invalid_login
    gateway = EmattersGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Dodgy Details', response.message
  end
end
