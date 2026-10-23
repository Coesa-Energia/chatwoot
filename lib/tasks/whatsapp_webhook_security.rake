namespace :whatsapp do
  desc 'Secure existing 360dialog channels: generate a webhook secret and re-register the webhook URL with it'
  # WhatsApp webhooks are always authenticated. 360dialog does not sign them, so the webhook URL carries a
  # secret token. New channels get one automatically; run this once for channels created before that.
  # Saving a channel generates the secret (before_validation) and re-registers the webhook with 360dialog
  # (provider config validation). Until it runs, those channels' webhooks are rejected with 401.
  task secure_360dialog_webhooks: :environment do
    channels = Channel::Whatsapp.where(provider: 'default')
    puts "Found #{channels.count} 360dialog channel(s)"

    channels.find_each do |channel|
      if channel.provider_config['webhook_secret'].present?
        puts "[skip] #{channel.phone_number}: already has a webhook secret"
      elsif channel.save
        puts "[ok]   #{channel.phone_number}: secret generated and webhook re-registered"
      else
        puts "[FAIL] #{channel.phone_number}: #{channel.errors.full_messages.join(', ')}"
      end
    end
  end
end
