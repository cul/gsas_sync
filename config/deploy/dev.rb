# frozen_string_literal: true

set :stage, :dev
set :branch, 'deployment'
server 'diglib-service-prod1.cul.columbia.edu', user: fetch(:remote_user), roles: %w[production_app]
