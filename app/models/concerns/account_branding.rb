# The account's own logos (uploaded in Settings > Account) and how the brand is shown in the sidebar header:
# logo above the name, logo beside the name, logo only or name only.
#   - `logo`: the main logo.
#   - `collapsed_logo`: the image shown when the sidebar is collapsed (a small icon works best).
#   - settings.brand_text_image: which of the two sits next to the account name ('logo' or 'collapsed_logo').
module AccountBranding
  extend ActiveSupport::Concern

  BRAND_DISPLAYS = %w[logo_name logo_name_inline logo name].freeze
  DEFAULT_BRAND_DISPLAY = 'logo_name'.freeze
  BRAND_TEXT_IMAGES = %w[logo collapsed_logo].freeze
  DEFAULT_BRAND_TEXT_IMAGE = 'logo'.freeze
  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  LOGO_MAX_SIZE = 2.megabytes

  class_methods do
    # The account whose brand stands for the whole installation (login page, favicon): the first one with a logo.
    def installation_brand_account
      joins(:logo_attachment).order(:id).first
    end
  end

  included do
    has_one_attached :logo
    has_one_attached :collapsed_logo
    validate :validate_logo
    validate :validate_brand_display
    validate :validate_brand_text_image
  end

  def brand_display
    settings['brand_display'].presence || DEFAULT_BRAND_DISPLAY
  end

  def brand_text_image
    settings['brand_text_image'].presence || DEFAULT_BRAND_TEXT_IMAGE
  end

  # The image for the collapsed sidebar, when one was uploaded.
  def collapsed_logo_url
    return unless collapsed_logo.attached?

    Rails.application.routes.url_helpers.rails_blob_path(collapsed_logo, only_path: true)
  end

  # The uploaded logo, or the one found when the account was created (website lookup), if any.
  def logo_url
    return Rails.application.routes.url_helpers.rails_blob_path(logo, only_path: true) if logo.attached?

    custom_attributes['logo'].presence
  end

  private

  def validate_logo
    { logo: logo, collapsed_logo: collapsed_logo }.each do |name, image|
      next unless image.attached?

      errors.add(name, 'must be a PNG, JPEG, WebP or GIF image') unless LOGO_CONTENT_TYPES.include?(image.blob.content_type)
      errors.add(name, 'must be 2 MB or smaller') if image.blob.byte_size > LOGO_MAX_SIZE
    end
  end

  def validate_brand_display
    value = settings['brand_display']
    errors.add(:settings, 'brand_display is invalid') if value.present? && BRAND_DISPLAYS.exclude?(value)
  end

  def validate_brand_text_image
    value = settings['brand_text_image']
    errors.add(:settings, 'brand_text_image is invalid') if value.present? && BRAND_TEXT_IMAGES.exclude?(value)
  end
end
