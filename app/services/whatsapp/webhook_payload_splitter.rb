# Meta can batch several messages or statuses (and several entries/changes) into one
# webhook. The inbound pipeline only reads the first item of each, so anything else in
# the batch would be dropped silently. This fans a batched payload out into one payload
# per item, each processed (and serialized per contact) by its own job.
#
# Payloads with at most one item, and non-Meta payloads (360dialog, etc.), are returned
# unchanged so the single-message path behaves exactly as before.
class Whatsapp::WebhookPayloadSplitter
  ITEM_KEYS = %w[messages statuses message_echoes].freeze
  CONTACT_REF_KEYS = %w[from from_user_id from_parent_user_id to to_user_id to_parent_user_id].freeze
  CONTACT_ID_KEYS = %w[wa_id user_id parent_user_id].freeze

  def self.split(payload)
    new(payload).split
  end

  def initialize(payload)
    @payload = payload.with_indifferent_access
  end

  def split
    return [@payload] unless @payload[:object] == 'whatsapp_business_account'

    items = collect_items
    return [@payload] if items.size <= 1

    items.map { |entry_index, change_index, key, item| build_payload(entry_index, change_index, key, item) }
  end

  private

  def collect_items
    Array(@payload[:entry]).each_with_index.flat_map do |entry, entry_index|
      Array(entry[:changes]).each_with_index.flat_map do |change, change_index|
        change_items(change, entry_index, change_index)
      end
    end
  end

  def change_items(change, entry_index, change_index)
    value = change[:value] || {}
    ITEM_KEYS.flat_map do |key|
      Array(value[key]).map { |item| [entry_index, change_index, key, item] }
    end
  end

  def build_payload(entry_index, change_index, key, item)
    entry = @payload[:entry][entry_index]
    change = entry[:changes][change_index]
    value = change[:value].except(*ITEM_KEYS).merge(key => [item])
    value[:contacts] = contacts_for(change[:value], item) if value.key?(:contacts)

    @payload.merge(entry: [entry.merge(changes: [change.merge(value: value)])])
  end

  # The job reads `contacts.first` as the sender, so keep only the contact that belongs
  # to this item (falling back to the full list when none can be matched).
  def contacts_for(value, item)
    contacts = Array(value[:contacts])
    refs = item.to_h.values_at(*CONTACT_REF_KEYS).compact_blank
    matched = contacts.select { |contact| contact.to_h.values_at(*CONTACT_ID_KEYS).compact_blank.intersect?(refs) }
    matched.presence || contacts
  end
end
