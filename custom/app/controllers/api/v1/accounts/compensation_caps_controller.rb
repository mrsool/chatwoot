class Api::V1::Accounts::CompensationCapsController < Api::V1::Accounts::BaseController
  before_action :ensure_caps_feature_enabled
  before_action :fetch_setting
  before_action :check_authorization

  # Two first saves can both pass the find-or-build in `for`; the unique account index rejects the loser.
  rescue_from ActiveRecord::RecordNotUnique, with: :render_concurrent_save

  def show; end

  def update
    @setting.assign_attributes(permitted_params)
    @setting.updated_by = Current.user
    @setting.save!
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.join(', '), attributes: e.record.errors.attribute_names },
           status: :unprocessable_entity
  end

  private

  def render_concurrent_save
    render json: { message: 'Compensation caps were just saved by someone else. Reload and try again.', attributes: [] },
           status: :unprocessable_entity
  end

  # Blank strings become nil so a cleared cap falls back to MBO's value instead of reading as 0.
  def permitted_params
    params.require(:compensation_caps).permit(*CompensationCapSetting::CAP_FIELDS).to_h.transform_values(&:presence)
  end

  def fetch_setting
    @setting = CompensationCapSetting.for(Current.account)
  end

  def check_authorization
    super(@setting)
  end

  def ensure_caps_feature_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('fazaa_compensation_caps')
  end
end
