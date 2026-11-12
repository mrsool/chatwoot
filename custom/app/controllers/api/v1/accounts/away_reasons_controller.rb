class Api::V1::Accounts::AwayReasonsController < Api::V1::Accounts::BaseController
  before_action :ensure_wfm_feature_enabled
  before_action :fetch_away_reason, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @away_reasons = Current.account.away_reasons
    @away_reasons = @away_reasons.active unless include_inactive?
  end

  def create
    @away_reason = Current.account.away_reasons.create!(permitted_params)
  end

  def update
    @away_reason.update!(permitted_params)
  end

  def destroy
    @away_reason.update!(active: false)
    head :ok
  end

  private

  def include_inactive?
    ActiveModel::Type::Boolean.new.cast(params[:all]) && Current.account_user.administrator?
  end

  def permitted_params
    params.require(:away_reason).permit(:name, :active, :position)
  end

  def fetch_away_reason
    @away_reason = Current.account.away_reasons.find(params[:id])
  end

  def ensure_wfm_feature_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('fazaa_wfm')
  end
end
