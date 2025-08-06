# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GsasSync::EmailClient do
  # GLOBAL TESTING OBJECTS (ALL OTHERS SCOPED TO EXAMPLE GROUPS OR EXAMPLES)
  test_log_file_name = 'test_log_file.log'
  test_config = {
    'host' => 'test_smtp_server',
    'port' => 0,
    'sender_address' => 'test_sender_email',
    'success_recipients' => ['test_success_email', 'second_test_success_email', 'third_test_success_email'],
    'failure_recipients' => ['test_failure_email', 'second_test_failure_email', 'third_test_failure_email']
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
    allow(GsasSync::Config).to receive(:success_recipients).and_return(test_config['success_recipients'])
    allow(GsasSync::Config).to receive(:failure_recipients).and_return(test_config['failure_recipients'])
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

  describe '#make_and_send_email' do
    # fix
    it 'correctly formats success email and calls send_email' do
      expect(test_email_client).to receive(:send_email).with(subject: GsasSync::EmailClient::SUCCESS_SUBJECT,
                                                             body: GsasSync::EmailClient::SUCCESS_BODY,
                                                             log_message: 'Success email sent',
                                                             recipients: test_config['success_recipients'])
      test_email_client.make_and_send_email(success: true)
    end

    # fix
    it 'correctly formats failure email and calls send_email' do
      expect(test_email_client).to receive(:send_email).with(subject: GsasSync::EmailClient::FAILURE_SUBJECT,
                                                             body: GsasSync::EmailClient::FAILURE_BODY,
                                                             log_message: 'Failure email sent',
                                                             recipients: test_config['failure_recipients'])
      test_email_client.make_and_send_email(success: false)
    end
  end

  describe '#send_email' do
    before do
      allow(Mail).to receive(:deliver)
    end

    # fix
    it 'sends an email for each recipient' do
      num_recipients = GsasSync::Config.success_recipients.length
      expect(Mail).to receive(:deliver).exactly(num_recipients).times
      test_email_client.send_email(subject: 'test', body: 'test', log_message: 'test',
                                   recipients: test_config['success_recipients'])
    end
  end
end
