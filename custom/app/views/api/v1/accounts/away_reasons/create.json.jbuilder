json.payload do
  json.partial! 'api/v1/models/away_reason', formats: [:json], away_reason: @away_reason
end
