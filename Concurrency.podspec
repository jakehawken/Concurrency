Pod::Spec.new do |s|
  s.name             = 'Concurrency'
  s.version          = '2.0.0'
  s.summary          = 'A small toolkit for handling concurrency in Swift.'

  s.description      = <<-DESC
  Concurrency is a simple but handy toolkit for dealing with asynchronous code in Swift.
  My goal is to simplify how asynchronous code is performed, and provide the cleanest, leanest interfaces for accomplishing that.
  Tags: Promise, Future, Deferred, Result, generics, Concurrency, asynchronous, async
  DESC

  s.homepage         = 'https://github.com/jakehawken/Concurrency'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'jakehawken' => 'https://github.com/jakehawken' }
  s.source           = { :git => 'https://github.com/jakehawken/Concurrency.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/geeksthenewcool'

  s.platform              = :ios, "11.4"
  s.ios.deployment_target = '11.4'
  s.swift_version = '4.2'

  s.source_files = 'Source/*'
end
