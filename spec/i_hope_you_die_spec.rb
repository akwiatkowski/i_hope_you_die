require 'spec_helper'
require 'yaml'

describe IHopeYouDie do
  it 'check cwu' do
    config = YAML::load(File.open('spec/private/data.yaml'))

    i = IHopeYouDie.new
    i.domain = config[:domain]
    i.login = config[:login]
    i.password = config[:password]

    i.auth!
    data = i.check_pesels(config[:pesels])

    puts data.to_yaml

  end
end
