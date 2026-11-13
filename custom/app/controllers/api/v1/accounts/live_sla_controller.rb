class Api::V1::Accounts::LiveSlaController < Api::V1::Accounts::BaseController
  FILTER_PARAMS = %i[inbox_id team_id assignee_id label sla_policy_id cr_code country].freeze

  before_action :ensure_live_sla_enabled
  before_action :check_admin_authorization?

  def index
    @board = Fazaa::LiveSlaBoard.new(account: Current.account, filters: params.permit(*FILTER_PARAMS).to_h).call
  end

  private

  def ensure_live_sla_enabled
    return if Current.account.feature_enabled?('sla') && Current.account.feature_enabled?('fazaa_sla_live')

    render json: { error: 'Live SLA is not enabled for this account' }, status: :forbidden
  end
end
