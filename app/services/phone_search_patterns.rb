# Builds ILIKE patterns for searching contact phone numbers typed in any common format.
#
# Stored numbers are E.164 (+5511999990001), so only digits are compared: "(11) 99999-0001",
# "11999990001" and "5511999990001" all match. For Brazilian numbers the mobile "ninth digit"
# is also tried both ways, so "11 9999-0001" finds +5511999990001 and the reverse.
#
# The raw query pattern is always included, so searches that are not phone numbers behave as before.
class PhoneSearchPatterns
  MIN_DIGITS = 4
  PHONE_LIKE = /\A[\d\s()+\-.]+\z/
  BRAZIL_COUNTRY_CODE = '55'.freeze

  def self.for(query)
    new(query).patterns
  end

  def initialize(query)
    @query = query.to_s.strip
  end

  def patterns
    ["%#{@query}%", *digit_patterns].uniq
  end

  private

  def digit_patterns
    return [] unless @query.match?(PHONE_LIKE)

    digits = @query.gsub(/\D/, '')
    return [] if digits.length < MIN_DIGITS

    [digits, *ninth_digit_variants(digits)].map { |variant| "%#{variant}%" }
  end

  # Brazilian national numbers are DDD (2 digits) + 8 digits (old) or 9 digits (mobile, starts with 9).
  def ninth_digit_variants(digits)
    prefix, national = split_country_code(digits)

    case national.length
    when 10 then ["#{prefix}#{national[0, 2]}9#{national[2..]}"]
    when 11 then national[2] == '9' ? ["#{prefix}#{national[0, 2]}#{national[3..]}"] : []
    else []
    end
  end

  def split_country_code(digits)
    return ['', digits] unless digits.start_with?(BRAZIL_COUNTRY_CODE) && [12, 13].include?(digits.length)

    [BRAZIL_COUNTRY_CODE, digits[2..]]
  end
end
