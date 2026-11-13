json.payload do
  json.array! @away_reasons do |away_reason|
    json.partial! 'api/v1/models/away_reason', formats: [:json], away_reason: away_reason
  end
end
