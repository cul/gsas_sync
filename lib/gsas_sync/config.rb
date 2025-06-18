# frozen_string_literal: true

# GsasSync::Config is a class for retrieving configuration data from the included
# configuration yaml file
# The class follows the singleton patten; ensuring this data is instantiated once and
# only once while the script runs
class GsasSync
  class Config
    CONFIG_LOCATION = 'config/config.yml'

    class << self
      attr_accessor :dry_run

      # Validates that the config file exists, and the listed storage and logs directories exist as well
      def validate_config
        err_t = GsasSync::Exceptions::GsasError
        raise err_t, 'No config file provided.' unless File.exist? CONFIG_LOCATION
        raise err_t, 'Storage directory in config file does not exist.' unless File.exist? storage_directory
        raise err_t, 'The logs directory in config file does not exist.' unless File.exist? logs_directory
      end

      def sftp_server
        config['sftp_server']
      end

      def sftp_server_str
        "#{config['sftp_server']['user']}@#{config['sftp_server']['host']}"
      end

      def mail_server
        config['mail_server']
      end

      def logs_directory
        config['logs']['directory']
      end

      def storage_directory
        config['storage']['directory']
      end

      private

      def config
        @config ||= init_config_file
      end

      def init_config_file
        raise GsasSync::Exceptions::GsasError, 'Config File could not be loaded' unless File.exist?(CONFIG_LOCATION)

        config_contents = File.read(CONFIG_LOCATION)
        YAML.load(config_contents)['config'] # TODO: use safe_load?
      end
    end
  end
end
