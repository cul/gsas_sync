# frozen_string_literal: true

set :stage, :test
set :branch, 'deployment'
server 'diglib-service-prod1.cul.columbia.edu', user: fetch(:remote_user)
