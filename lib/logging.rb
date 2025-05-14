# frozen_string_literal: true

# The Logging module provides utilities for formatting the logger for the gsas_sync script
module Logging
  def self.format_logger(logger)
    logger.formatter = proc do |severity, datetime, progname, msg|
      severity_str = rainbowize_severity_str(severity)
      datetime_str = Rainbow(datetime).silver.faint
      progname_str = Rainbow(progname).cyan.bright
      "#{severity_str} (#{datetime_str}) - #{progname_str} : #{msg}\n"
    end
  end

  def self.rainbowize_severity_str(str)
    res = Rainbow(" #{str} ").bright
    case str
    when 'DEBUG'
      res.blue.bg(:white)
    when 'INFO'
      res.green.bg(:white)
    when 'WARN'
      res.bg(:yellow)
    when 'ERROR'
      res.red.bg(:yellow)
    when 'FATAL'
      res.white.bg(:red)
    end
  end
end
