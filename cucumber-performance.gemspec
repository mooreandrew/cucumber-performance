Gem::Specification.new do |s|
  s.name        = 'cucumber-performance'
  s.version     = '0.0.3'
  s.date        = '2014-09-27'
  s.summary     = ""
  s.description = "This gem adds function libraries for performance testing and the steps to support the run"
  s.authors     = ["Andrew Moore"]
  s.email       = 'mooreandrew@gmail.com'
  s.files       = ["lib/cucumber-performance.rb", "lib/cucumber-performance/cucumber-steps.rb", "lib/cucumber-performance/functions.rb", "lib/cucumber-performance/views/index.html.erb"]
  s.homepage    =
    'https://github.com/mooreandrew/cucumber-performance'
  s.license       = 'MIT'
  s.add_dependency 'cucumber', '>= 1.3.15'
  s.add_dependency 'sinatra', '>= 1.4.5'
  s.add_dependency 'curb', '>= 0.8.6'
end
