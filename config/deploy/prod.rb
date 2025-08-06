# frozen_string_literal: true

set :stage, :prod
set :branch, 'deployment'
server 'diglib-service-prod1.cul.columbia.edu', user: fetch(:remote_user), roles: %w[app]
