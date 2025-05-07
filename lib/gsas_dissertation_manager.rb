# frozen_string_literal: true

class GsasDissertationManager
  include Cul::PreservationUtils::FilePath

  attr_accessor :config

  def initialize(config_file)
    @config = load_config_file(config_file)
  end

  private

  def load_config_file(config_file)
    config_contents = File.read(config_file)
    @config = YAML.load(config_contents)
  end
end
