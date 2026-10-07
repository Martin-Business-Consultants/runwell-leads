# frozen_string_literal: true

# Settings › Leads: the points each event is worth, the score that qualifies
# a lead, who sequence emails come from, and per form whether its
# submissions make leads and which sequence a new one joins (Leads::Settings).
class Settings::LeadsController < Settings::BaseController
  include PluginGated
  plugin :leads

  requires_capability "leads:read", only: :show
  requires_capability "leads:write", only: :update

  def show
    @settings = Leads::Settings.current
    @forms = Form.ordered
    @sequences = Leads::Sequence.ordered
  end

  def update
    Leads::Settings.update(params.require(:settings).permit(:threshold, :from_name, :from_email,
      points: Leads::Settings::POINTS.keys, capture: {}).to_unsafe_h)
    redirect_to settings_leads_path, notice: "Lead settings saved"
  end
end
