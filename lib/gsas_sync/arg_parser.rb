# frozen_string_literal: true

module GsasSync::ArgParser
  ############################## GLOBALS #######################################
  USAGE_STR = "Usage:\n\truby gsas_sync_main.rb [options]"

  DEFAULT_STDOUT_LOG_LEVEL = Logger::DEBUG

  ############################## METHODS #######################################
  # Parse the arguments given thru the command line to determine the old and new
  # CSV files we are comaring.
  def self.parse_cl_args
    options = {}
    OptionParser.new { |opts|
      opts.banner = USAGE_STR
      # TODO : debug why log level cant be specified from command line...
      opts.on('-l [LLVL]', '--log-level [LLVL]',
              "Specify the runtime log level (debug, info, warn, error, fatal - default is '#{log_lvl_to_str(DEFAULT_STDOUT_LOG_LEVEL)}')")
      options[:help] = opts.help
    }.parse!(into: options)

    log_lvl = options.key?(:log_lvl) ? options[:log_lvl] : DEFAULT_STDOUT_LOG_LEVEL

    { log_lvl: log_lvl }
  end

  def self.log_lvl_to_str(lvl)
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

  def self.str_to_log_lvl(lvl)
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
end
