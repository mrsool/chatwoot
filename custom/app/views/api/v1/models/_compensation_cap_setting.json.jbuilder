CompensationCapSetting::VALUE_LIMITS.each do |field|
  json.set! field, setting[field]&.to_f
end
CompensationCapSetting::COUNT_LIMITS.each_key do |field|
  json.set! field, setting[field]
end
json.updated_at setting.persisted? ? setting.updated_at.iso8601 : nil
json.updated_by setting.updated_by ? { id: setting.updated_by.id, name: setting.updated_by.name } : nil
