require 'rails_helper'

describe PhoneSearchPatterns do
  def patterns(query)
    described_class.for(query)
  end

  it 'always includes the raw query so non-phone searches are unchanged' do
    expect(patterns('Maria')).to eq(['%Maria%'])
  end

  it 'adds a digits-only pattern for formatted numbers' do
    expect(patterns('(11) 99999-0001')).to include('%11999990001%')
  end

  it 'adds the alternative without the ninth digit for a Brazilian mobile number' do
    expect(patterns('11999990001')).to include('%11999990001%', '%1199990001%')
  end

  it 'adds the alternative with the ninth digit for an 8-digit Brazilian number' do
    expect(patterns('1199990001')).to include('%1199990001%', '%11999990001%')
  end

  it 'keeps the country code when generating the alternatives' do
    expect(patterns('+55 11 99999-0001')).to include('%5511999990001%', '%551199990001%')
    expect(patterns('551199990001')).to include('%551199990001%', '%5511999990001%')
  end

  it 'does not treat a DDD 55 national number as having a country code' do
    expect(patterns('55999990001')).to include('%55999990001%', '%5599990001%')
  end

  it 'does not generate digit patterns for very short numeric input' do
    expect(patterns('123')).to eq(['%123%'])
  end

  it 'does not generate digit patterns for text mixed with digits' do
    expect(patterns('ana 11999990001')).to eq(['%ana 11999990001%'])
  end

  it 'handles nil and blank queries' do
    expect(patterns(nil)).to eq(['%%'])
    expect(patterns('  ')).to eq(['%%'])
  end
end
