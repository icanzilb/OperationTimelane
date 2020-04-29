Pod::Spec.new do |s|
  s.name             = 'OperationTimelane'
  s.version          = '0.9.0'
  s.summary          = 'OperationTimelane provides operations bindings for profiling asynchronous code with the Timelane Instrument. Consult the README for the specific APIs to use in order to make the most out of OperationTimelane.'

  s.description      = <<-DESC
OperationTimelane provides operations bindings for profiling asynchronous code with the Timelane Instrument.
                       DESC

  s.homepage         = 'https://github.com/icanzilb/OperationTimelane'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Marin Todorov' => 'touch-code-magazine@underplot.com' }
  s.source           = { :git => 'https://github.com/icanzilb/OperationTimelane.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/icanzilb'

  s.source_files = 'Sources/**/*.swift'

  s.swift_versions = ['5.0']
  s.requires_arc          = true
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.watchos.deployment_target = '6.0'
  s.tvos.deployment_target = '13.0'
  
  s.source_files = 'Sources/**/*.swift'  
  s.frameworks = 'Foundation'
  
  s.dependency 'TimelaneCore', '~> 1'
end
