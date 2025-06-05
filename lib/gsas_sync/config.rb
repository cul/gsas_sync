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

      def storage
        config['storage']
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
