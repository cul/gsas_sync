# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GsasSync::EmailClient do
  # GLOBAL TESTING OBJECTS (ALL OTHERS SCOPED TO EXAMPLE GROUPS OR EXAMPLES)
  test_recipient = 'test_recipient'
  test_subject = 'test_subject'
  test_body = 'test_body'
  test_log_file_name = 'test_log_file.log'
  test_config = {
    'host' => 'test_smtp_server',
    'port' => 0,
    'sender_address' => 'test_sender_email',
    'recipients' => ['test_recipient_email']
  }
  let(:logger_double) { instance_double(Logger) }
  let(:test_email_client) { described_class.new(test_log_file_name) } # 'test_log_file.log') }

  before do
    # Mock logging
    allow(GsasSync::Logger).to receive(:stdout_logger).and_return(logger_double)
    allow(logger_double).to receive(:debug)
    allow(logger_double).to receive(:info)
    # Mock config
    allow(GsasSync::Config).to receive(:mail_server).and_return(test_config)
    allow(GsasSync::Config).to receive(:logs_directory).and_return('test_logs_dir')

    # Class specific mock objects
  end

  # TESTS
  describe '#initialize' do
    it 'reads values from config to set instance variables' do
      expect(GsasSync::Config).to receive(:mail_server)
      test_email_client
    end

    it 'configures the Mail class defaults after initialization' do
      expect(Mail).to receive(:defaults)
      test_email_client
    end
  end

  describe '#log_file_str' do
    it 'returns the correct absolute path to log file' do
      test_path = '/absolute/path'
      allow(FileUtils).to receive(:pwd).and_return(test_path)

      expect(test_email_client.log_file_str).to eq("#{test_path}/test_logs_dir/#{test_log_file_name}")
    end
  end

  describe '#send_success_email_all' do
    it 'calls #send_success_email for each email in @recipients' do
      num_recipients = GsasSync::Config.mail_server['recipients'].length
      expect(test_email_client).to receive(:send_success_email).exactly(num_recipients).times

      test_email_client.send_success_email_all
    end
  end

  describe '#send_success_email' do
    it 'calls Mail::deliver' do
      allow(Mail).to receive(:deliver)

      expect(Mail).to receive(:deliver)
      test_email_client.send_success_email(test_recipient, test_subject, test_body)
    end
  end

  describe '#send_failure_email_all' do
    it 'calls #send_failure_email for each email in @recipients' do
      num_recipients = GsasSync::Config.mail_server['recipients'].length
      expect(test_email_client).to receive(:send_failure_email).exactly(num_recipients).times

      test_email_client.send_failure_email_all
    end
  end

  describe '#send_failure_email' do
    it 'calls Mail::deliver' do
      allow(Mail).to receive(:deliver)

      expect(Mail).to receive(:deliver)
      test_email_client.send_failure_email(test_recipient, test_subject, test_body)
    end
  end
end
