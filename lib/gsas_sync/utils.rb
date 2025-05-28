# frozen_string_literal: true

module GsasSync::Utils
  def error_string(err)
    "Error [#{err.class.name}] : #{err.message}"
  end
end
