json.payload do
  json.array! @agents do |agent|
    json.partial! 'api/v1/models/agent', formats: [:json], resource: agent
    json.see_all_conversations @see_all_user_ids.include?(agent.id)
    json.in_rotation @rotation_user_ids.include?(agent.id)
  end
end
