json.payload do
  json.partial! 'api/v1/models/compensation_cap_setting', formats: [:json], setting: @setting
end
