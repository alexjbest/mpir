require 'psych'
Yaml = Psych.load_file("data.yml")
def ress(name)
  Yaml['functions'].each do |fun|
    if fun['name'] == name
      fun['benchmarks'].each do |b|
        puts b['results'][986].to_s + " "+  b['results'][993].to_s + " " + b['results'][1000].to_s + "  " + b['hash']
      end; 0
    end; 0
  end; 0
end; 0
