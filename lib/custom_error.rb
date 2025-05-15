# frozen_string_literal: true

class CustomError < StandardError
  def initialize(msg = 'My default message')
    super
  end
end
