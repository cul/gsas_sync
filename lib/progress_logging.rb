# frozen_string_literal: true

module ProgressLogging
  # attr_accessor :filepath, :log_file
  DEF_DIR = 'logs'
  DEF_FN = 'progress.log'
  # @step = 0

  # class << self; attr_accessor :step end

  # Opens and returns the elog file object
  def self.initProgressLogging(logs_dir = DEF_DIR, filename = DEF_FN, logger)
    @step = 0
    filepath = "#{logs_dir}/#{filename}"
    logger.debug "Initializing Error Logs at #{filepath}"
    begin
      FileUtils.mkdir(logs_dir) unless File.directory?(logs_dir)
      File.delete(filepath) if File.file?(filepath)
      File.open(filepath, 'w')
    rescue StandardError => e
      logger.error("Unable to create #{filepath}")
      logger.error(e)
      if filepath == "#{DEF_DIR}/#{DEF_FN}"
        logger.fatal('Default options were used -- fatal. Exiting...')
        exit(1)
      end
      begin
        logger.debug("Attempting to create progress logs with default values (#{DEF_DIR}/#{DEF_FN})...")
        File.mkdir(DEF_DIR) unless File.directory?(DEF_DIR)
        File.delete(DEF_FN) if File.file?(DEF_FN)
        File.open("#{DEF_DIR}/#{DEF_FN}", 'w')
      rescue StandardError
        logger.fatal("Unable to create #{filepath}")
        logger.fatal(e)
        exit(1)
      end
    end
  end

  def self.err(log, err, msg = '')
    log.puts "\tAn exception was caught:\n\t\tError: #{err}#{"\nMessage: #{msg}" unless msg.empty?}"
  end

  def self.fatal(log, err, msg = '')
    log.puts "\tA fatal exception was caught:\n\t\tError: #{err}#{unless msg.empty?
                                                                    "\n\t\tMessage: #{msg}"
                                                                  end}\nProgram will exit now..."
  end

  def self.start_step(log, title, desc = '')
    str = "==================================================\n" \
          "Step: #{@step}.) #{title}#{' -- ' unless desc.empty?}#{desc}"
    @step += 1
    log.puts str
  end

  def self.log(log, msg)
    log.puts "\t#{msg}\n"
  end
end
