# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ServicesController, '(JavaScript fixtures)', type: :controller do
  include JavaScriptFixturesHelpers

  let(:admin)     { create(:admin) }
  let(:namespace) { create(:namespace, name: 'frontend-fixtures' )}
  let(:project)   { create(:project_empty_repo, namespace: namespace, path: 'services-project') }
  let!(:service)  { create(:prometheus_service, project: project) }

  render_views

  before(:all) do
    clean_frontend_fixtures('services/prometheus')
  end

  before do
    sign_in(admin)
  end

  after do
    remove_repository(project)
  end

  it 'services/prometheus/prometheus_service.html' do
    get :edit, params: {
      namespace_id: namespace,
      project_id: project,
      id: service.to_param
    }

    expect(response).to be_successful
  end
end
