# frozen_string_literal: true

module ArgParser
  ############################## GLOBALS #######################################
  # CLI Usage information
  USAGE_STR = "Usage:\n\truby gsas_sync_main.rb [options]"

  # Default output filename
  DEFAULT_OUTPUT_FILE_PATH = File.join(Dir.pwd, 'duplicate_analysis.csv').freeze

  DEFAULT_CONFIG_LOCATION = 'config/config.yml'
  DEFAULT_ELOG_LOCATION = 'logs/error_log.log'
  DEFAULT_LLOG_LEVEL = Logger::DEBUG

  ############################## METHODS #######################################
  # Parse the arguments given thru the command line to determine the old and new
  # CSV files we are comaring.
  def self.parse_cl_args
    options = {}
    OptionParser.new { |opts|
      opts.banner = USAGE_STR
      opts.on('-c [CONF]', '--config [CONF]', 'Specify the location of the config.yml file')
      opts.on('-e [ELOG]', '--elog [ELOG]',
              'Specify the location to store error log file during runtime (elogs will be emailed to product owners upon failure in production)')
      # TODO : debug why log level cant be specified from command line...
      opts.on('-l [LLVL]', '--llog-level [LLVL]',
              "Specify the runtime log level (debug, info, warn, error, fatal - default is '#{llog_lvl_to_str(DEFAULT_LLOG_LEVEL)}')")
      options[:help] = opts.help
    }.parse!(into: options)

    config_file = options.key?(:config) ? options[:config] : DEFAULT_CONFIG_LOCATION
    elog_file = options.key?(:elog) ? options[:elog] : DEFAULT_ELOG_LOCATION
    llog_lvl = options.key?(:llog_lvl) ? options[:llog_lvl] : DEFAULT_LLOG_LEVEL

    { config_file: config_file, elog_file: elog_file, llog_lvl: llog_lvl }
  end

  def self.llog_lvl_to_str(lvl)
    case lvl
    when Logger::DEBUG
      'debug'
    when Logger::INFO
      'info'
    when Logger::WARN
      'warn'
    when Logger::ERROR
      'error'
    when Logger::FATAL
      'fatal'
    end
  end

  def self.str_to_llog_lvl(lvl)
    case lvl
    when 'debug'
      Logger::DEBUG
    when 'info'
      Logger::INFO
    when 'warn'
      Logger::WARN
    when 'error'
      Logger::ERROR
    when 'fatal'
      Logger::FATAL
    end
  end

  def self.rainbowize_severity_str(str)
    res = Rainbow(" #{str} ")
    case str
    when 'DEBUG'
      res.blue.bg(:white)
    when 'INFO'
      res.green.bg(:white)
    when 'WARN'
      res.indianred.bg(:yellow)
    when 'ERROR'
      res.red.bg(:yellow)
    when 'FATAL'
      res.red.bright.bg(:yellow)
    end
  end
end
